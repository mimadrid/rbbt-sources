require 'rbbt-util'
require 'rbbt/resource'

module Reactome
  extend Resource
  self.subdir = "share/databases/Reactome"

  def self.organism(org="Hsa")
    require 'rbbt/sources/organism'
    Organism.default_code(org)
  end

  Reactome.claim Reactome.protein_pathways, :proc  do
    #url = "http://www.reactome.org/download/current/uniprot_2_pathways.stid.txt"
    url = "http://reactome.org/download/current/Ensembl2Reactome.txt"
    tsv = TSV.open(url, :key_field => 0, :fields => [1], :merge => true, :type => :flat, :tsv_grep => "Homo sapiens")
    tsv.key_field = "Ensembl Gene ID"
    tsv.fields = ["Reactome Pathway ID"]
    tsv.namespace = Reactome.organism
    tsv.to_s
  end

  Reactome.claim Reactome.protein_pathways_all, :proc  do
    #url = "http://www.reactome.org/download/current/uniprot_2_pathways.stid.txt"
    url = "http://reactome.org/download/current/Ensembl2Reactome_All_Levels.txt"
    tsv = TSV.open(url, :key_field => 0, :fields => [1], :merge => true, :type => :flat, :tsv_grep => "Homo sapiens")
    tsv.key_field = "Ensembl Gene ID"
    tsv.fields = ["Reactome Pathway ID"]
    tsv.namespace = Reactome.organism
    tsv.to_s
  end


  Reactome.claim Reactome.pathway_names, :proc  do
    #url = "http://www.reactome.org/download/current/uniprot_2_pathways.stid.txt"
    url = "http://www.reactome.org/download/current/UniProt2Reactome.txt"
    tsv = TSV.open(Open.open(url), :key_field => 1, :fields => [3], :type => :single)
    tsv.key_field = "Reactome Pathway ID"
    tsv.fields = ["Pathway Name"]
    tsv.namespace = Reactome.organism
    tsv.to_s
  end

  Reactome.claim Reactome.pathway_pathway, :proc  do
    #url = "http://www.reactome.org/download/current/uniprot_2_pathways.stid.txt"
    url = "http://reactome.org/download/current/ReactomePathwaysRelation.txt"
    tsv = TSV.open(Open.open(url), :type => :flat, :merge => true)
    tsv.key_field = "Reactome Pathway ID"
    tsv.fields = ["Reactome Pathway ID"]
    tsv.namespace = Reactome.organism
    tsv.to_s
  end

  Reactome.claim Reactome.protein_protein, :proc  do
    url = "http://www.reactome.org/download/current/homo_sapiens.interactions.txt.gz"
    tsv = TSV.open(CMD.cmd('cut -f 1,4,7,8,9|sed "s/UniProt://g;s/,/;/g"', :in => Open.open(url), :pipe => true), :type => :double, :merge => true)
    tsv.key_field = "UniProt/SwissProt Accession"
    tsv.fields = ["Interactor UniProt/SwissProt Accession", "Interaction type", "Reactions", "PMID"]
    tsv.namespace = Reactome.organism
    tsv.to_s
  end

  #Reactome.claim Reactome.protein_pathways, :proc  do
  #  #url = "http://www.reactome.org/download/current/uniprot_2_pathways.stid.txt"
  #  url = "http://www.reactome.org/download/current/UniProt2Reactome.txt"
  #  tsv = TSV.open(Open.open(url), :key_field => 0, :fields => [1], :merge => true, :type => :double)
  #  tsv.key_field = "UniProt/SwissProt Accession"
  #  tsv.fields = ["Reactome Pathway ID"]
  #  tsv.namespace = Reactome.organism
  #  tsv.to_s
  #end

  #Reactome.claim Reactome.pathway_names, :proc  do
  #  #url = "http://www.reactome.org/download/current/uniprot_2_pathways.stid.txt"
  #  url = "http://www.reactome.org/download/current/UniProt2Reactome.txt"
  #  tsv = TSV.open(Open.open(url), :key_field => 1, :fields => [2], :type => :single)
  #  tsv.key_field = "Reactome Pathway ID"
  #  tsv.fields = ["Pathway Name"]
  #  tsv.namespace = Reactome.organism
  #  tsv.to_s
  #end

  #Reactome.claim Reactome.protein_protein, :proc  do
  #  url = "http://www.reactome.org/download/current/homo_sapiens.interactions.txt.gz"
  #  tsv = TSV.open(CMD.cmd('cut -f 1,4,7,8,9|sed "s/UniProt://g;s/,/;/g"', :in => Open.open(url), :pipe => true), :type => :double, :merge => true)
  #  tsv.key_field = "UniProt/SwissProt Accession"
  #  tsv.fields = ["Interactor UniProt/SwissProt Accession", "Interaction type", "Reactions", "PMID"]
  #  tsv.namespace = Reactome.organism
  #  tsv.to_s
  #end

end

if defined? Entity 
  module ReactomePathway
    extend Entity
    self.format = "Reactome Pathway ID"
    
    self.annotation :organism

    def self.name_index
      @name_index ||= Reactome.pathway_names.tsv(:persist => true, :key_field => "Reactome Pathway ID", :fields => ["Pathway Name"], :type => :single)
    end

    def self.gene_index
      @gene_index ||= Reactome.protein_pathways.tsv(:persist => true, :key_field => "Reactome Pathway ID", :fields => ["UniProt/SwissProt Accession"], :type => :flat, :merge => true)
    end

    def self.filter(query, field = nil, options = nil, entity = nil)
      return true if query == entity

      return true if self.setup(entity.dup, options.merge(:format => field)).name.index query

      false
    end

    property :name => :array2single do
      @name ||= ReactomePathway.name_index.values_at *self
    end

    property :genes => :array2single do
      @genes ||= ReactomePathway.gene_index.values_at(*self).
        each{|gene| gene.organism = organism if gene.respond_to? :organism }
    end

    property :url => :single do
      "http://www.reactome.org/cgi-bin/eventbrowser_st_id?ST_ID=#{ self }"
    end
  end

  if defined? Gene and Entity === Gene
    module Gene
      property :reactome_pathways => :array2single do
        @reactome_pathways ||= Reactome.protein_pathways.tsv(:persist => true, :key_field => "UniProt/SwissProt Accession", :fields => ["Reactome Pathway ID"], :type => :flat, :merge => true).values_at(*self.to("UniProt/SwissProt Accession")).
          each{|pth| pth.organism = organism if pth.respond_to? :organism }.tap{|o| ReactomePathway.setup(o, organism)}
      end
    end
  end
end

Log.tsv Reactome.protein_pathways.produce.tsv if __FILE__ == $0
Log.tsv Reactome.protein_pathways_all.produce.tsv if __FILE__ == $0
Log.tsv Reactome.pathway_names.produce(true).tsv if __FILE__ == $0
Log.tsv Reactome.pathway_pathway.produce.tsv if __FILE__ == $0
