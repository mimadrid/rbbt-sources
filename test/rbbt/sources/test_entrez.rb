require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require 'rbbt/sources/entrez'
require 'test/unit'

class TestEntrez < Test::Unit::TestCase
  $yeast_tax = 559292

  def test_entrez2native
    tax    = $yeast_tax
    fix    = proc{|line| line.sub(/SGD:S0/,'S0') }
    select = proc{|line| line.match(/SGD:S0/)}
    lexicon = Entrez.entrez2native(tax, :fix => fix, :select => select)

    assert(lexicon['855611'].include? 'S000005056') 
  end

  def test_entrez2pubmed
    tax   = $yeast_tax

    data = Entrez.entrez2pubmed(tax)
    assert(data['850320'].include? '1574125') 
  end

  def test_getonline
    geneids = 9129

    assert_match(/PRP3 pre-mRNA processing factor/s, Entrez.get_online(geneids))

    geneids = [9129,9]
    assert_match(/PRP3 pre-mRNA processing factor/s, Entrez.get_online(geneids)[9129])
  end

  def test_getgene
    geneids = 9129
    assert_equal([["PRP3 pre-mRNA processing factor 3 homolog (S. cerevisiae)"]], Entrez.get_gene(geneids).description)

    geneids = [9129, 728049]
    assert_equal([["PRP3 pre-mRNA processing factor 3 homolog (S. cerevisiae)"]], Entrez.get_gene(geneids)[9129].description)
  end

  def test_similarity
    assert(Entrez.gene_text_similarity(9129, "PRP3 pre-mRNA processing factor 3 homolog (S. cerevisiae)") > 0)
    assert_equal(0, Entrez.gene_text_similarity("NON EXISTENT GENEID", "PRP3 pre-mRNA processing factor 3 homolog (S. cerevisiae)"))
  end

end


