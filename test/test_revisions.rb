require 'helper'

class TestRevisions < Test::Unit::TestCase 
  
  Time.zone = 'Eastern Time (US & Canada)'
  
  
  context "a response" do
  
    setup do
      @response = Response.create({
        :title  => "This is a post about Donkey",
        :slug   => "this-is-a-post-about-donkey",
        :body   => "This is the body of Donkey",
      })
    end
        
    context "When saving with revisions" do
      
      setup do
        @response.status = 'published'
        @response.intro = "donkey intro"
        pretend_now_is(5.minutes.from_now) do
          assert @response.save_revision
          @revision = @response.latest_revision
        end
      end
      
      should "save a revision even in draft mode" do
        @response.revisions.delete_all
        @response.status = 'draft'
        assert @response.save_revision
        @response.reload
        assert_equal 1, @response.revisions.size
      end
    
      should "save a revision that copies all fields" do
        assert_equal @revision.title, @response.title
        assert_equal @revision.body, @response.body
      end
      
      should "set more updated timestamps" do
        assert @revision.created_at > @response.created_at
        assert @revision.updated_at > @response.updated_at
      end
      
      should "say it's a revision of the first guy" do
        assert @revision.revision_of = @response.id
      end
      
      should "set the status to revision" do
        assert_equal 'revision', @revision.status
      end

      should "copy attributes not yet saved to the DB" do
        @response.reload
        assert_equal "donkey intro", @revision.intro
        assert_not_equal @revision.intro, @response.intro
      end
      
      should "not copy ignored attributes" do
        assert_not_equal @revision.slug, @response.slug
      end
      
      should "return true when it saves" do
        assert @response.save_revision
      end
      
      should "return false when it doesn't save" do
        @response.title = nil
        assert_equal false, @response.save_revision
      end
      
      should "attach errors to the base object if a revision save fails" do
        @response.title = nil
        @response.save_revision
        assert_equal "can't be blank", @response.errors.on(:title)
      end
      
      should "return true when it saves!" do
        assert @response.save_revision!
      end
      
      should "raise an exception when it saves! and has bad data" do
        assert_raises ActiveRecord::RecordNotSaved do
          @response.title = nil
          @response.save_revision!          
        end
      end
                 
    end
    
    context "when accessing revisions" do
      
      should "return null if there aren't revisions" do
        assert_equal nil, @response.latest_revision
      end
      
      should "show if there are no pending revisions if none exist" do
        assert_equal false, @response.pending_revisions?
      end
      
      context "with a revision" do
        setup do
          @response.status = 'published'
          pretend_now_is(5.minutes.from_now) do
            @response.save_revision!
            @response.save_revision!
          end
        end
        
        should "return the revision if there is one" do
          latest = Response.find(:first, :conditions => 'status=\'revision\'', :order => 'id DESC')
          assert_equal latest.id, @response.latest_revision.id
        end
        
        should "say there are pending revisions if there are some" do
          assert @response.pending_revisions?
        end
        
        should "say there aren't pending revisions if they are old" do
          @response.updated_at = 2.days.from_now
          assert_equal false, @response.pending_revisions?
        end
        
        
      end
      

      
    end

    context "when applying a revision" do
            
      setup do
        @response.update_attribute(:status, 'published')
        assert @response.save_revision
        @revision = @response.latest_revision
        @revision.title = "new revision title"
        @revision.body = "new revision body"
        @revision.slug = "new-donkey-slug"
        @revision.save
      end
      
      should "copy over parameters we want (title, body, etc.)" do
        assert @response.apply_revision
        assert_equal @revision.title, @response.title
        assert_equal @revision.body, @response.body
      end
      
      should "do nothing (ie not raise an exception)" do
        @response.revisions.delete_all
        assert_equal false, @response.apply_revision
      end
      
      should "not copy over parameters we want to keep (slug, status, revision_of, etc.)" do
        @response.apply_revision
        assert_equal 'published', @response.status
        assert_equal nil, @response.revision_of
        assert_not_equal @response.slug, @revision.slug
      end
      
      should "not save the response" do
        @response.apply_revision
        @response.reload
        assert_not_equal @revision.title, @response.title
      end
      
      should "save the response when using bang" do
        @response.apply_revision!
        @response.reload
        assert_equal @revision.title, @response.title
        assert_equal 'published', @response.status
        assert_equal "this-is-a-post-about-donkey", @response.slug #still keep og slug
      end
      
      should "throw an exception on bang when no response" do
        @response.revisions.delete_all
        assert_raises RuntimeError do
          @response.apply_revision!
        end
      end
      
      context "with multiple revisions" do
        setup do
          @response.save_revision
          @newer_revision = @response.latest_revision
          @newer_revision.update_attribute(:title, 'even newer title')
        end

        should "copy over the latest revision if nothing passed" do
          @response.apply_revision
          assert_equal @newer_revision.title, @response.title
        end

        should "use a selected revision if passed" do
          @response.apply_revision(@revision)
          assert_equal @revision.title, @response.title
        end      
      end
    
    end
  end
end
