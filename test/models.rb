class Response < ActiveRecord::Base
  validates_presence_of :title
  has_revisions :ignore => ['slug']
end