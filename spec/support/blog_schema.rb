BLOG_SCHEMA = {
  users: [
    { name: :id, type: :String },
    { name: :first_name, type: :String },
    { name: :last_name, type: :String },
    { name: :email, type: :String },
  ],
  posts: [
    { name: :id, type: :String },
    { name: :subject, type: :String },
    { name: :body, type: :String },
    { name: :author_id, type: :String },
  ],
  comments: [
    { name: :id, type: :String },
    { name: :body, type: :String },
    { name: :post_id, type: :String },
    { name: :commenter_id, type: :String },
  ],
  categories: [
    { name: :id, type: :String },
    { name: :name, type: :String },
  ],
  categories_to_posts: [
    { name: :post_id, type: :String },
    { name: :category_id, type: :String },
  ],
}
