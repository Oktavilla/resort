require 'spec_helper'

module Resort
  describe Sortable do

    subject { Article.new }

    context 'when included' do
      it 'creates previous and next relationships' do
        subject.should respond_to(:previous, :next)
      end

      it 'includes base with InstanceMethods' do
        subject.class.ancestors.should include(Sortable::InstanceMethods)
      end
      it 'extend base with ClassMethods' do
        (class << subject.class; self; end).ancestors.should include(Sortable::ClassMethods)
      end
      it 'defines a siblings method' do
        subject.class.instance_methods.should include(:siblings)
      end
    end

    describe 'ClassMethods' do

      describe "ordering" do
        before do
          Article.destroy_all

          4.times do |i|
            Article.create(:name => i.to_s)
          end

          Article.find_by_name('0').append_to(Article.find_by_name('3'))
          Article.find_by_name('1').append_to(Article.find_by_name('3'))
          Article.find_by_name('2').append_to(Article.find_by_name('3'))

          @article1 = Article.find_by_name('3')
          @article2 = Article.find_by_name('2')
          @article3 = Article.find_by_name('1')
          @article4 = Article.find_by_name('0')
        end

        describe "#first_in_order" do
          it 'returns the first element of the list' do
            Article.first_in_order.should == @article1
          end
        end

        describe "#last_in_order" do
          it 'returns the last element of the list' do
            Article.last_in_order.should == @article4
          end
        end

        describe "#ordered" do
          it 'returns all elements ordered' do
            Article.ordered.should == [@article1, @article2, @article3, @article4]
          end
        end

        describe "#ordered with faulty referentials" do
          before do
            @article2.update_attribute(:next_id, @article1.id)
          end

          it 'returns all elements unsorted' do
            Article.ordered.should == [@article1, @article2, @article3, @article4].reverse
          end
        end

        after do
          Article.destroy_all
        end
      end
    end

    describe "siblings" do
      before do
        one_list = List.create(:name => 'My list')
        another_list = List.create(:name => 'My other list')

        4.times do |i|
          one_list.items << ListItem.new(:name => "My list item #{i}")
          another_list.items << ListItem.new(:name => "My other list item #{i}")
        end

      end

      describe "#first_in_order" do
        it 'returns the first element of the list' do
          List.find_by_name('My list').items.first_in_order.name.should == "My list item 0"
          List.find_by_name('My other list').items.first_in_order.name.should == "My other list item 0"
        end
      end

      describe "#last_in_order" do
        it 'returns the last element of the list' do
          List.find_by_name('My list').items.last_in_order.name.should == "My list item 3"
          List.find_by_name('My other list').items.last_in_order.name.should == "My other list item 3"
        end
      end

      describe "#ordered" do
        it 'returns all elements ordered' do
          List.find_by_name('My list').items.ordered.map(&:name).should == ['My list item 0', 'My list item 1', 'My list item 2', 'My list item 3']
          List.find_by_name('My other list').items.ordered.map(&:name).should == ['My other list item 0', 'My other list item 1', 'My other list item 2', 'My other list item 3']
        end

        it 'does not raise when ordering without scope' do
          expect {
            ListItem.ordered
          }.not_to raise_error
        end
      end

      after do
        List.destroy_all
        ListItem.destroy_all
      end
    end

    describe "after create" do
      context 'when there are no siblings' do
        it 'prepends the element' do
          article = Article.create(:name => 'first!')

          article.should be_first
          article.next.should be_nil
          article.previous.should be_nil
        end
      end
      context 'otherwise' do
        it 'appends the element' do
          Article.create(:name => "1")
          Article.create(:name => 'last!')

          article = Article.find_by_name('last!')
          first = Article.find_by_name('1')

          article.should be_last
          article.next_id.should be_nil
          article.previous.name.should == '1'

          first.next_id.should eq(article.id)
        end
      end
      after do
        Article.destroy_all
      end

      context "with custom siblings" do

        context 'when there are no siblings' do
          it 'prepends the element' do
            one_list = List.create(:name => 'My list')
            another_list = List.create(:name => 'My other list')
            item = ListItem.create(:name => "My list item", :list => one_list)

            item.should be_first
            item.next.should be_nil
            item.previous.should be_nil
          end
        end
        context 'otherwise' do
          it 'appends the element' do
            one_list = List.create(:name => 'My list')
            another_list = List.create(:name => 'My other list')
            ListItem.create(:name => "1", :list => one_list)
            ListItem.create(:name => "last!", :list => one_list)

            first = ListItem.find_by_name('1')
            last = ListItem.find_by_name('last!')

            last.should be_last
            last.next_id.should be_nil
            last.previous.name.should == '1'

            first.next_id.should eq(last.id)
          end
        end
        after do
          List.destroy_all
          ListItem.destroy_all
        end
      end
    end

    describe "after destroy" do
      context 'when the element is the first' do
        it 'removes the element' do
          article = Article.create(:name => 'first!')
          article2 = Article.create(:name => 'second!')
          article3 = Article.create(:name => 'last!')

          article = Article.find_by_name('first!')
          article.destroy

          article2 = Article.find_by_name('second!')

          article2.should be_first
          article2.previous.should be_nil
        end
      end
      context 'when the element is in the middle' do
        it 'removes the element' do
          article = Article.create(:name => 'first!')
          article2 = Article.create(:name => 'second!')
          article3 = Article.create(:name => 'last!')

          article = Article.find_by_name('first!')

          article2 = Article.find_by_name('second!')
          article2.destroy

          article = Article.find_by_name('first!')
          article3 = Article.find_by_name('last!')

          article.should be_first
          article.next.name.should == 'last!'
          article3.previous.name.should == 'first!'
        end
      end
      context 'when the element is last' do
        it 'removes the element' do
          article = Article.create(:name => 'first!')
          article2 = Article.create(:name => 'second!')
          article3 = Article.create(:name => 'last!')

          article3.destroy

          article2.next.should be_nil
        end
      end
      after do
        Article.destroy_all
      end
    end

    describe 'InstanceMethods' do
      before do
        Article.destroy_all
        Article.create(:name => "1")
        Article.create(:name => "2")
        Article.create(:name => "3")
        Article.create(:name => "4")

        @article1 = Article.find_by_name('1')
        @article2 = Article.find_by_name('2')
        @article3 = Article.find_by_name('3')
        @article4 = Article.find_by_name('4')
      end

      describe "#push" do
        it "appends the element to the list" do
          @article1.push

          article1 = Article.find_by_name('1')
          article1.previous.should == @article4
          article1.next.should be_nil
        end
        context 'when the article is already last' do
          it 'does nothing' do
            @article4.push

            @article4.previous.name.should == '3'
            @article4.next.should be_nil
          end
        end
      end

      describe "#prepend" do
        it "prepends the element" do
          @article3.prepend

          article3 = Article.find_by_name('3')

          article3.should be_first
          article3.previous.should be_nil
          article3.next.name.should == '1'
        end
        context 'when the article is already first' do
          it 'does nothing' do
            @article1.prepend

            @article1.previous.should be_nil
            @article1.next.name.should == '2'
          end
        end
      end

      describe "#append_to" do
        context 'appending 1 after 2' do
          it "appends the element after another element" do
            @article1.append_to(@article2)

            article1 = Article.find_by_name('1')
            article1.next.name.should == '3'
            article1.previous.name.should == '2'
            @article3.previous.name.should == '1'
          end

          it "sets the other element as first" do
            @article1.append_to(@article2)

            article2 = Article.find_by_name('2')
            article2.next.name.should == '1'
            article2.should be_first
          end
        end

        context 'appending 1 after 3' do
          it "appends the element after another element" do
            @article1.append_to(@article3)

            article1 = Article.find_by_name('1')
            article1.should_not be_first
            article1.previous.name.should == '3'
            article1.next.name.should == '4'

            @article3.next.name.should == '1'
            @article4.previous.name.should == '1'
          end

          it 'resets the first element' do
            @article1.append_to(@article3)

            article2 = Article.find_by_name('2')
            article2.should be_first
            article2.previous.should be_nil
          end
        end

        context 'appending 2 after 3' do
          it "appends the element after another element" do
            @article2.append_to(@article3)

            article1 = Article.find_by_name('1')
            article1.next.name.should == '3'

            article2 = Article.find_by_name('2')
            article2.previous.name.should == '3'
            article2.next.name.should == '4'

            @article3.previous.name.should == '1'
            @article3.next.name.should == '2'

            @article4.previous.name.should == '2'
          end
        end
        context 'appending 2 after 4' do
          it "appends the element after another element" do
            @article2.append_to(@article4)

            article1 = Article.find_by_name('1')
            article3 = Article.find_by_name('3')

            article1.next.name.should == '3'
            article3.previous.name.should == '1'

            article2 = Article.find_by_name('2')
            article2.previous.name.should == '4'
            article2.should be_last

            @article4.next.name.should == '2'
          end
        end
        context 'appending 4 after 2' do
          it "appends the element after another element" do
            @article4.append_to(@article2)

            article3 = Article.find_by_name('3')
            article3.next.should be_nil
            article3.previous.name.should == '4'

            article4 = Article.find_by_name('4')
            @article2.next.name.should == '4'
            article4.previous.name.should == '2'
            article4.next.name.should == '3'
          end
        end
        context 'appending 3 after 1' do
          it "appends the element after another element" do
            @article3.append_to(@article1)

            article1 = Article.find_by_name('1')
            article1.next.name.should == '3'

            article2 = Article.find_by_name('2')
            article2.previous.name.should == '3'
            article2.next.name.should == '4'

            article3 = Article.find_by_name('3')
            article3.previous.name.should == '1'
            article3.next.name.should == '2'

            @article4.previous.name.should == '2'
          end
        end

        context 'when the article is already after the other element' do
          it 'does nothing' do
            @article2.append_to(@article1)

            article1 = Article.find_by_name('1')
            article2 = Article.find_by_name('2')

            article1.next.name.should == '2'
            article2.previous.name.should == '1'
          end
        end
      end
    end

  end
end
