require 'rbbt'
require 'rbbt/sources/biomart'
require 'rbbt/sources/entrez'

def tsv_file(url, native, extra, options = {})
  options = Misc.add_defaults options, :persist => false, :keep_empty => true

  case
  when Array === native
    options = Misc.add_defaults options, :key => native.last 
    key_field = native.first
  when (String === native or Integer === native)
    options = Misc.add_defaults options, :key => native
    key_field = nil
  else
    key_field = nil
  end

  case
  when (Array === extra and Array === extra.first)
    options = Misc.add_defaults options, :fields => extra.collect{|e| e.last}
    fields = extra.collect{|e| e.first}
  when (Array === extra and not Array === extra.first)
    options = Misc.add_defaults options, :fields => extra
    fields = (1..extra.length).to_a.collect{|i| "Field#{i}"}
  else
    fields = nil
  end

  tsv = TSV.open(Open.open(url), options)
  tsv.key_field ||= key_field
  tsv.fields    ||= fields
  tsv
end

def merge_entrez(data, taxs, native, fix = nil, select = nil)
  entrez =  Entrez.entrez2native(taxs, :fix => fix, :select => select)
  entrez.key_field = "Entrez Gene ID"
  entrez.fields = [native]
  entrez

  data.attach entrez, "Entrez Gene ID"
end

def merge_biomart(lexicon, db, native, other, match = nil)
  match ||= native.first
  lexicon.attach BioMart.tsv(db, native, other)
end
