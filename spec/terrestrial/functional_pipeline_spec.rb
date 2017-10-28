require "terrestrial/functional_pipeline"
RSpec.describe Terrestrial::FunctionalPipeline do
  subject(:pipeline) { Terrestrial::FunctionalPipeline.new }

  let(:input) { double(:input) }
  let(:step1) { double(:step1, call: "step1_result") }
  let(:step2) { double(:step2, call: "step2_result") }
  let(:step3) { double(:step3, call: "step3_result") }

  describe "#append" do
    it "returns a new pipeline" do
      expect(pipeline.append(:step1, step1)).not_to be(pipeline)
    end

    it "appends a step to the existing steps" do
      p1 = pipeline.append(:step1, step1)
      result, _ = p1.call(input)

      expect(result).to eq("step1_result")
    end
  end

  context "three step pipeline" do
    let(:pipeline) do
      Terrestrial::FunctionalPipeline.from_array(
        [
          [:step1, step1],
          [:step2, step2],
          [:step3, step3],
        ]
      )
    end

    describe "#call" do
      it "calls the first step with the input" do
        pipeline.call(input)

        expect(step1).to have_received(:call).with(input)
      end

      it "calls the second step with the result of the first" do
        pipeline.call(input)

        expect(step2).to have_received(:call).with("step1_result")
      end

      it "calls the thrid step with the result of the second" do
        pipeline.call(input)

        expect(step3).to have_received(:call).with("step2_result")
      end

      it "returns the result of the last step" do
        result, _ = pipeline.call(input)

        expect(result).to eq("step3_result")
      end

      it "returns the intermediate results of all steps" do
        _, intermediates = pipeline.call(input)

        expect(intermediates).to eq([
          [:input, input],
          [:step1, "step1_result"],
          [:step2, "step2_result"],
          [:step3, "step3_result"],
        ])
      end

      context "when called with a block" do
        it "yields the result of each step to the block" do
          yielded = []

          pipeline.call(input) do |name, result|
            yielded << [name, result]
          end

          expect(yielded).to eq([
            [:step1, "step1_result"],
            [:step2, "step2_result"],
            [:step3, "step3_result"],
          ])
        end
      end
    end

    describe "#describe" do
      it "returns the list of named steps" do
        expect(pipeline.describe).to eq([:step1, :step2, :step3])
      end
    end

    describe "#take_until" do
      it "returns a new a pipeline" do
        expect(pipeline.take_until(:step2)).to be_a(Terrestrial::FunctionalPipeline)
      end

      describe "the new pipeline" do
        subject(:new_pipeline) { pipeline.take_until(:step2) }

        it "contains steps from the beginning up to specified step" do
          expect(new_pipeline.describe).to eq([:step1, :step2])
        end

        context "when executed" do
          it "returns the result of the steps"  do
            result, _ = new_pipeline.call(input)

            expect(result).to eq("step2_result")
          end
        end
      end
    end

    describe "#drop_until" do
      it "returns a new a pipeline" do
        expect(pipeline.drop_until(:step2)).to be_a(Terrestrial::FunctionalPipeline)
      end

      describe "the new pipeline" do
        subject(:new_pipeline) { pipeline.drop_until(:step2) }

        it "contains steps that appear before the specified step" do
          expect(new_pipeline.describe).to eq([:step3])
        end

        context "when executed" do
          it "starts execution with the step after the specified one" do
            result, _ = new_pipeline.call(input)

            expect(step3).to have_received(:call).with(input)
          end

          it "does not execute steps dropped from the original pipeline" do
            result, _ = new_pipeline.call(input)

            expect(step1).not_to have_received(:call)
            expect(step2).not_to have_received(:call)
          end

          it "returns the result of the steps"  do
            result, _ = new_pipeline.call(input)

            expect(result).to eq("step3_result")
          end
        end
      end
    end

    describe "#each" do
    end
  end
end
