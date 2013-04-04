require 'spec_helper'

class OutputTests < SimpleDelegator
  def initialize(terminal)
    super
    @print_num = 0
  end

  def next_print_num
    @print_num += 1
  end

  def output
    say "section #{next_print_num}"
  end

  def output_no_breaks
    say "section #{next_print_num} "
  end
  
  def section_same_line
    section { output_no_breaks; say 'word' }
  end

  def section_no_breaks
    section { output_no_breaks }
  end

  def section_one_break
    section { output }
  end

  def sections_equal_bottom_top
    section(:bottom => 1) { output }
    section(:top => 1) { output }
  end

  def sections_larger_bottom
    section(:bottom => 2) { output }
    section(:top => 1) { output }
  end

  def sections_larger_top
    section(:bottom => 1) { output }
    section(:top => 2) { output }
  end

  def sections_four_on_three_lines
    section { output }
    section(:top => 1) { output_no_breaks }
    section(:bottom => 1) { output }
    section(:top => 1) { output }
  end

  def outside_newline
    section(:bottom => -1) { output }
    say "\n"
    section(:top => 1) { output }
  end

  def section_1_1
    section(:top => 1, :bottom => 1) { say "section" }
  end

  def section_paragraph
    paragraph { say "section" }
  end

  # call section without output to reset spacing to 0
  def reset
    __getobj__.instance_variable_set(:@margin, 0)
  end
end

describe HighLineExtension do
  subject{ MockHighLineTerminal.new }

  it "should wrap the terminal" do
    subject.wrap_at = 10
    subject.say "Lorem ipsum dolor sit amet"
    output = subject.read
    output.should match "Lorem\nipsum\ndolor sit\namet"
  end
  it "should wrap the terminal" do
    subject.wrap_at = 16
    subject.say "Lorem ipsum dolor sit amet"
    output = subject.read
    output.should match "Lorem ipsum\ndolor sit amet"
  end
  it "should not wrap the terminal" do
    subject.wrap_at = 50
    subject.say "Lorem ipsum dolor sit amet"
    output = subject.read
    output.should match "Lorem ipsum dolor sit amet"
  end
  it "should wrap the terminal when using color codes" do
    subject.wrap_at = 10
    subject.say subject.color("Lorem ipsum dolor sit amet Lorem ipsum dolor sit amet", :red)
    output = subject.read
    output.should match "Lorem\nipsum\ndolor sit\namet Lorem\nipsum\ndolor sit\namet"
  end
  it "should wrap the terminal with other escape characters" do
    subject.wrap_at = 10
    subject.say "Lorem ipsum dolor sit am\eet"
    output = subject.read
    output.should match "Lorem\nipsum\ndolor sit\nam\eet"
  end
  it "should wrap the terminal when words are smaller than wrap length" do
    subject.wrap_at = 3
    subject.say "Antidisestablishmentarianism"
    output = subject.read
    output.should match "Ant\nidi\nses\ntab\nlis\nhme\nnta\nria\nnis\nm"
  end

  it "should wrap a table based on a max width" do
    subject.table([["abcd efgh", "12345 67890 a"]], :width => 8).should == [
      "abcd 12345",
      "efgh 67890",
      "     a   "
    ]
  end

  it "should not wrap a cells that are too wide based on a max width" do
    subject.table([["abcdefgh", "1234567890"]], :width => 8).should == [
      "abcdefgh 1234567890",
    ]
  end

  it "should wrap a table based on columns" do
    subject.table([["abcd", "123"]], :width => [1]).should == [
      "a 123",
      "b ",
      "c ",
      "d ",
    ]
  end

  context "sections" do
    let(:tests) { OutputTests.new(subject) }

    it "should print out a paragraph with open endline on the same line" do
      tests.section_same_line
      subject.read.should == "section 1 word\n"
    end

    it "should print out a section without any line breaks" do
      tests.section_no_breaks
      subject.read.should == "section 1 \n"
    end

    it "should print out a section with trailing line break" do
      tests.section_one_break
      subject.read.should == "section 1\n"
    end

    it "should print out 2 sections with matching bottom and top margins generating one space between" do
      tests.sections_equal_bottom_top
      subject.read.should == "section 1\n\nsection 2\n"
    end

    it "should print out 2 sections with larger bottom margin generating two spaces between" do
      tests.sections_larger_bottom
      subject.read.should == "section 1\n\n\nsection 2\n"
    end

    it "should print out 2 sections with larger top margin generating two spaces between" do
      tests.sections_larger_top
      subject.read.should == "section 1\n\n\nsection 2\n"
    end

    it "should print out 4 sections and not collapse open sections" do
      tests.sections_four_on_three_lines
      subject.read.should == "section 1\n\nsection 2 \nsection 3\n\nsection 4\n"
    end

    it "should show the equivalence of paragaph to section(:top => 1, :bottom => 1)" do
      tests.section_1_1
      section_1_1 = tests.read
      
      tests = OutputTests.new(MockHighLineTerminal.new)

      tests.section_paragraph
      paragraph = tests.read

      section_1_1.should == paragraph
    end
    it "should combine sections" do
      tests.section_1_1
      tests.section_paragraph

      subject.read.should == "section\n\nsection\n"
    end

    it "should not collapse explicit newline sections" do
      tests.outside_newline
      subject.read.should == "section 1\n\n\nsection 2\n"
    end
  end
end