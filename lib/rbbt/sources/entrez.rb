require 'rbbt-util'
require 'rbbt/util/tsv'
require 'rbbt/bow/bow'
require 'set'

module Entrez

  Rbbt.share.databases.entrez.gene_info.define_as_url 'ftp://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz'
  Rbbt.share.databases.entrez.gene2pubmed.define_as_url 'ftp://ftp.ncbi.nih.gov/gene/DATA/gene2pubmed.gz'

  def self.entrez2native(taxs, options = {})
    options = Misc.add_defaults options, :key => 1, :fields => 5, :persistence => true, :merge => true

    taxs = [taxs] unless Array === taxs
    options.merge! :grep => taxs.collect{|t| "^" + t.to_s}
    
    tsv = Rbbt.share.databases.entrez.gene_info.tsv :flat, options
    tsv.key_field = "Entrez Gene ID"
    tsv.fields    = ["Native ID"]
    tsv
  end

  def self.entrez2pubmed(taxs)
    options = {:key => 1, :fields => 2, :persistence => true, :merge => true}

    taxs = [taxs] unless taxs.is_a?(Array)
    options.merge! :grep => taxs.collect{|t| "^" + t.to_s}

    Rbbt.share.databases.entrez.gene2pubmed.tsv :flat, options
  end
  
  class Gene
    attr_reader :organism, :symbol, :description, :aka, :protnames, :summary, :comentaries

    def initialize(xml)
      return if xml.nil?

      @organism    = xml.scan(/<Org-ref_taxname>(.*)<\/Org-ref_taxname>/s)
      @symbol      = xml.scan(/<Gene-ref_locus>(.*)<\/Gene-ref_locus>/s)
      @description = xml.scan(/<Gene-ref_desc>(.*)<\/Gene-ref_desc>/s)
      @aka         = xml.scan(/<Gene-ref_syn_E>(.*)<\Gene-ref_syn_E>/s)
      @protnames   = xml.scan(/<Prot-ref_name_E>(.*)<\/Prot-ref_name_E>/s)
      @summary     = xml.scan(/<Entrezgene_summary>(.*)<\/Entrezgene_summary>/s)
      @comentaries = xml.scan(/<Gene-commentary_text>(.*)<\/Gene-commentary_text>/s)


    end

    # Joins the text from symbol, description, aka, protnames, and
    # summary
    def text
      #[@organism, @symbol, @description, @aka,  @protnames, @summary,@comentaries.join(". ")].join(". ") 
      [@symbol, @description, @aka,  @protnames, @summary].flatten.join(". ") 
    end
  end

  private 

  def self.get_online(geneids)

    genes_complete =  geneids.is_a?(Array) ? geneids : [geneids]

    genes = []
    Misc.divide(genes_complete, (genes_complete.length / 100) + 1).each do |geneids_list|
      begin
        Misc.try3times do
          url = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=gene&retmode=xml&id=#{geneids_list * ","}" 

          xml = Open.read(url, :wget_options => {:quiet => true}, :nocache => true)

          genes += xml.scan(/(<Entrezgene>.*?<\/Entrezgene>)/sm).flatten
        end
      rescue
        genes += geneids_list.collect{|g| nil}
      end
    end

    if geneids.is_a? Array
      list = Hash[*genes_complete.zip([nil]).flatten]
      genes.each{|gene|
        geneid = gene.match(/<Gene-track_geneid>(\d+)/)[1]
        geneid = geneid.to_i unless list.include? geneid
        list[geneid] = gene
      }
      return list
    else
      return genes.first
    end
  end

  public

  def self.gene_filename(id)
    'gene-' + id.to_s + '.xml'
  end

  def self.get_gene(geneid)
    return nil if geneid.nil?

    if Array === geneid
      missing = []
      list = {}

      geneid.each{|p|
        next if p.nil?
        if FileCache.found(gene_filename p)
          list[p] = Gene.new(Open.read(FileCache.path(gene_filename p)))
        else
          missing << p 
        end
      }

      return list unless missing.any?
      genes = get_online(missing)

      genes.each{|p, xml|
        filename = gene_filename p    
        FileCache.add(filename,xml) unless FileCache.found(filename)
        list[p] =  Gene.new(xml)
      }

      return list
    else
      filename = gene_filename geneid    

      if FileCache.found(filename)
        return Gene.new(Open.read(FileCache.path(filename)))
      else
        xml = get_online(geneid)
        FileCache.add(filename, xml) unless FileCache.found(filename)

        return Gene.new(xml)
      end
    end
  end

  # Counts the words in common between a chunk of text and the text
  # found in Entrez Gene for that particular gene. The +gene+ may be a
  # gene identifier or a Gene class instance.
  def self.gene_text_similarity(gene, text)

    case
    when Entrez::Gene === gene
      gene_text = gene.text
    when String === gene || Fixnum === gene
      begin
        gene_text =  get_gene(gene).text
      rescue CMD::CMDError
        return 0
      end
    else
      return 0
    end

    gene_words = gene_text.words.to_set
    text_words = text.words.to_set

    return 0 if gene_words.empty? || text_words.empty?

    common = gene_words.intersection(text_words)
    common.length / (gene_words.length + text_words.length).to_f
  end
end
