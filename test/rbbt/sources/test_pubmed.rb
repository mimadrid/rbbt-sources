require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

require 'rbbt/sources/pubmed'
require 'test/unit'

class TestPubMed < Test::Unit::TestCase

  def test_get_article
    pmid = '16438716'
    assert(PubMed.get_article(pmid).title == "Discovering semantic features in the literature: a foundation for building functional associations.")
    
    pmids = ['16438716', 17204154]
    assert(PubMed.get_article(pmids)[pmid].title == "Discovering semantic features in the literature: a foundation for building functional associations.")
  end
 
  def test_full_text
    pmid = '16438716'
    assert(PubMed.get_article(pmid).full_text =~ /Discovering/)
  end
 
  def test_query
    assert(PubMed.query('chagoyen[All Fields] AND ("loattrfull text"[sb] AND hasabstract[text])').include? '16438716')
  end

  def test_year
    pmid = '16438716'
    assert_equal "2006", PubMed.get_article(pmid).year
  end

  def test_bibentry
    assert("vazquez2008sent", PubMed::Article.make_bibentry('vazquez', 2008, "SENT: Semantic features in text"))
    assert("vazquez2008aes", PubMed::Article.make_bibentry('vazquez', 2008, "An Example System"))
  end
end


