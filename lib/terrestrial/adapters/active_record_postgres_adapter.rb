require "forwardable"

require "terrestrial/adapters/abstract_adapter"
require "terrestrial/inspection_string"

module Terrestrial
  module Adapters
    class ActiveRecordPostgresAdapter
      extend Forwardable
      include Adapters::AbstractAdapter

      def initialize(database)
        unless database.is_a? ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
          raise "no!"
        end
        @database = database
      end

      attr_reader :database
      private     :database

      def_delegators :database, *[
        :transaction,
      ]

      def tables
        database.tables.map(&:to_sym)
      end

      def primary_key(table_name)
        Array(database.primary_key(table_name)).map(&:to_sym)
      end

      def [](table_name)
        Dataset.new(
          self,
          arel_table(table_name),
        )
      end

      def upsert(record)
        if ENV["ADAPTER"] != "activerecord"
          raise "Using ActiveRecord adapter when set to #{ENV['ADAPTER']}"
        end
        sql = generate_upsert_sql(record)
        result = database.exec_query(sql)
        row = result.to_a.first.symbolize_keys
        record.on_upsert(row)
        nil
      rescue Object => e
        raise UpsertError.new(record.namespace, record.to_h, e)
      end

      def delete(record)
        table = arel_table(record.namespace)
        constraints = map_to_arel_constraints(table, record.identity)

        delete_manager = Arel::DeleteManager.new.from(table)
        constraints.each do |constraint|
          delete_manager.where(constraint)
        end
        database.exec_delete(delete_manager.to_sql)
      rescue Object => e
        raise UpsertError.new(record.namespace, record.to_h, e)
      end

      def changes_sql(record)
        generate_upsert_sql(record)
      rescue Object => e
        raise UpsertError.new(record.namespace, record.to_h, e)
      end

      def generate_upsert_sql(record)
        table_name = record.namespace
        insert = Insert.new(
          arel_table(table_name),
          conflict_fields(table_name),
          record,
          database,
        )
        database.build_insert_sql(insert)
      end

      def execute(sql)
        spec = caller.grep(/spec\/.*_spec.rb/)
        lazy_symbolize_keys(database.execute(sql))
      end

      def conflict_fields(table_name)
        primary_key(table_name) + unique_indexes(table_name)
      end

      def unique_indexes(table_name)
        database.indexes(table_name)
          .select { |index| index.unique }
          .map { |index| index.columns.map(&:to_sym) }
      end

      def relations
        database.tables - [:schema_migrations]
      end

      def relation_fields(relation_name)
        database.columns(relation_name).map { |col| col.name.to_sym }
      end

      private

      def select_from_arel_table(name)
        arel_table(name).project("*")
      end

      def arel_table(name)
        Arel::Table.new(name)
      end

      def arel_attribute(table, column_name, value)
        table[column_name].eq(value)
      end

      def lazy_symbolize_keys(db_result)
        db_result.lazy.map(&:symbolize_keys!)
      end

      def map_to_arel_constraints(arel_table, constraints)
        constraints.map { |k,v|
          if v.respond_to?(:to_sql)
            arel_table[k].in(Arel::Nodes::SqlLiteral.new(v.to_sql))
          elsif v.is_a?(Enumerable)
            arel_table[k].in(v)
          else
            arel_table[k].eq(v)
          end
        }
      end

      module WrapDelegate
        def wrap_delegators(target_name, method_names)
          method_names.each do |method_name|
            define_method(method_name) do |*args, &block|
              self.class.new(
                send(target_name).public_send(method_name, *args, &block)
              )
            end
          end
        end
      end

      class Dataset
        extend Forwardable
        extend WrapDelegate
        include Enumerable
        include InspectionString

        def inspectable_properties
          [:arel_table, :arel_select]
        end

        def initialize(adapter, arel_table, arel_select = nil)
          @adapter = adapter
          @arel_table = arel_table
          @arel_select = arel_select
        end

        attr_reader :adapter, :arel_table
        private     :adapter, :arel_table

        # wrap_delegators :dataset, [
        #   :select,
        #   :where,
        #   :clone,
        #   :order,
        # ]

        # def_delegators :dataset, *[
        #   :empty?,
        #   :delete,
        #   :opts,
        #   :sql,
        #   :reverse,
        # ]

        def select(*fields)
          field_list = fields.flatten(1)
          cs = clone_select
          cs.projections = []
          cs.project(map_to_arel_fields(field_list))
          new(cs)
        end

        def where(constraints)
          cs = clone_select
          cs.where(map_to_arel_constraints(constraints))
          new(cs)
        end

        def wheres
          arel_select.ast.cores.first.wheres
        end

        def cache_sql?
          false
        end

        def each(&block)
          adapter.execute(to_sql).each(&block)
        end

        QueryBuildError = Class.new(RuntimeError)

        def to_sql
          arel_select.to_sql
        rescue => og_error
          new_error = QueryBuildError.new(
            "Error building query from Arel\n" \
            "#{og_error.message}\n\n" \
            # "#{arel_select.ast.inspect.gsub(/ @/, "\n  @")}\n" \
          )
          raise new_error
        end

        def order(*field_names)
          direction = :asc
          direction_method = direction.downcase.to_sym
          arel_fields = map_to_arel_fields(field_names)

          cs = clone_select
          arel_fields.each do |af|
            cs.order(af.public_send(direction_method))
          end
          new(cs)
        end

        def reverse
          cs = clone_select
          cs.orders.map!(&:reverse)
          new(cs)
        end

        private

        def map_to_arel_constraints(constraints)
          constraints.map { |k,v|
            arel_field = name_to_arel_field(k)

            if v.respond_to?(:to_sql)
              arel_table[k].in(Arel::Nodes::SqlLiteral.new(v.to_sql))
            else
              case v
              when String,Symbol,Numeric
                arel_field.eq(v)
              when Enumerable
                arel_field.in(v)
              when Regexp
                arel_field.matches_regexp(v.source, v.casefold?)
              else
                binding.irb if ENV['ADAPTER'] != 'activerecord'
                warn "Don't *really* know how to build a where clause for that type #{v.class} #{v.inspect}"
                arel_field.eq(v)
              end
            end
          }
        end

        def map_to_arel_fields(fields)
          fields.map { |f| name_to_arel_field(f) }
        end

        def name_to_arel_field(field)
          arel_table[field]
        end

        def new(new_select)
          self.class.new(adapter, arel_table, new_select)
        end

        def clone_select
          arel_select.clone
        end

        def arel_select
          @arel_select ||= arel_table.project("*")
        end
      end

      class Insert
        def initialize(arel_table, conflict_fields, record, database)
          @arel_table = arel_table
          @conflict_fields = conflict_fields
          @record = record
          @database = database
        end

        attr_reader :arel_table, :record, :database

        def into
          "INTO #{arel_table.name} (#{columns_list}) VALUES"
        end

        def columns_list
          if primary_key_missing?
            record.updatable_attributes.keys.join(",")
          else
            record.attributes.keys.join(",")
          end
        end

        def values_list
          if primary_key_missing?
            values = record.updatable_attributes.values
          else
            values = record.attributes.values
          end

          parens(
            values
              .map { |v| database_type_cast(v) }
              .join(",")
          )
        end

        def conflict_target
          if @conflict_fields.any?
            parens(@conflict_fields.join(","))
          end
        end

        def returning
          "*"
        end

        def skip_duplicates?
          @conflict_fields.none?
        end

        def update_duplicates?
          record.identity_fields.any?
        end

        def raw_update_sql?
          false
        end

        def touch_model_timestamps_unless(&block)
          ""
        end

        def updatable_columns
          record.insertable.keys
        end

        private

        def primary_key_missing?
          record.identity_values.all?(&:nil?)
        end

        def database_type_cast(value)
          if value.respond_to?(:to_sql)
            value.to_sql
          else
            cast_value = database.type_cast(value)
            if cast_value.is_a?(String)
              cast_value = "'" + database.quote_string(cast_value) + "'"
            end
            cast_value
          end
        end

        def parens(string)
          "(#{string})"
        end
      end
    end
  end
end
