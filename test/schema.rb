ActiveRecord::Schema.define(:version => 1) do 
  create_table "responses", :force => true do |t|
    t.text     "body"
    t.string   "title"
    t.string   "slug"
    t.string   "intro"
    t.datetime "published_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "status"
    t.integer  "revision_of"
  end
end