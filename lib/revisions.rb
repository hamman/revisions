module Revisions
  module ClassMethods
  
    STATUSES = ['draft', 'published', 'revision']
      
    def has_revisions opts={}
      class_attribute :unrevised_attributes
      
      has_many :revisions,  
        :class_name => self.name, 
        :conditions => "status='revision'",
        :foreign_key => 'revision_of'
      
      include InstanceMethods
      
      self.unrevised_attributes = opts[:ignore] || []
      self.unrevised_attributes.concat ['revision_of', 'status', 'created_at', 'updated_at', 'id']
    end
  
  end
  module InstanceMethods
    
    def self.included(klass)
      klass.extend(ClassMethods)
    end

    def published?
      status == 'published'
    end

    def revision?
      status == 'revision'
    end
    
    def draft?
      status == 'draft'
    end

    def save_revision
      new_copy = self.class.new
      cloned_attributes = self.clone_attributes
      self.unrevised_attributes.each {|a| cloned_attributes.delete(a) }
      new_copy.attributes=cloned_attributes
      new_copy.created_at = new_copy.updated_at = Time.zone.now
      new_copy.status = 'revision'
      new_copy.revision_of = self.id
      if new_copy.save
        true
      else
        self.errors.clear
        new_copy.errors.each do |attribute,message| 
          self.errors[attribute] << message
        end
        false
      end   
    end

    def save_revision!
      save_revision || raise(ActiveRecord::RecordNotSaved)
    end

    def latest_revision
      revisions.last
    end

    def pending_revisions?
      !latest_revision.nil? && latest_revision.updated_at > self.updated_at
    end

    # maps a revision's changes onto the main object
    def apply_revision(revision=nil)
      revision = latest_revision if revision.nil?
      unless revision.nil?
        revised_attributes = revision.attributes.reject {|k,v| self.unrevised_attributes.include?(k)}
        self.attributes=revised_attributes
        return true
      end
      false
    end

    def apply_revision!(revision=nil)
      if apply_revision(revision)
        save!
      else
        raise RuntimeError.new("No revision to apply!")
      end
    end    
      
  end
end


if defined?(ActiveRecord)
  ActiveRecord::Base.instance_eval { extend Revisions::ClassMethods }
end