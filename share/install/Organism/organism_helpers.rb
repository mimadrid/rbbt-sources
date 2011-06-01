$biomart_ensembl_gene = ['Ensembl Gene ID', 'ensembl_gene_id']
$biomart_ensembl_protein = ['Ensembl Protein ID', 'ensembl_peptide_id']
$biomart_ensembl_exon = ['Ensembl Exon ID', 'ensembl_exon_id']
$biomart_ensembl_transcript = ['Ensembl Transcript ID', 'ensembl_transcript_id']

$biomart_gene_positions = [
  ['Chromosome Name','chromosome_name'],
  ['Strand','strand'],
  ['Gene Start','start_position'],
  ['Gene End','end_position'],
]

$biomart_gene_sequence = [
  ['Gene Sequence','gene_exon_intron'],
]

#{{{ Transcript

$biomart_gene_transcript = [
  $biomart_ensembl_transcript
]

$biomart_transcript = [
  ['Transcript Start (bp)','transcript_start'],
  ['Transcript End (bp)','transcript_end'],
  $biomart_ensembl_protein,
  $biomart_ensembl_gene
]

$biomart_transcript_sequence = [
  ['cDNA','cdna'],
]

$biomart_transcript_3utr = [
  ["3' UTR", '3utr'],
]

$biomart_transcript_5utr = [
  ["5' UTR", '5utr'],
]


$biomart_protein_sequence = [
  ['Protein Sequence','peptide'],
]

#{{{ Exons

$biomart_transcript_exons = [
  $biomart_ensembl_exon,
  ['Exon Rank in Transcript','rank'],
]

$biomart_exons = [
  $biomart_ensembl_gene,
  ['Exon Strand','strand'],
  ['Exon Chr Start','exon_chrom_start'],
  ['Exon Chr End','exon_chrom_end'],
]

#{{{ Rules

file 'scientific_name' do |t|
  File.open(t.name, 'w') do |f| f.write $scientific_name end
end

file 'identifiers' do |t|
  identifiers = BioMart.tsv($biomart_db, $biomart_ensembl_gene, $biomart_identifiers, [], nil, :namespace => $namespace)

  $biomart_identifiers.each do |name, key, prefix|
    if prefix
      identifiers.process name do |field, key, values| field.each{|v| v.replace "#{prefix}:#{v}"} end
    end
  end

  entrez_synonyms = Rbbt.share.databases.entrez.gene_info.tsv :grep => $taxs.collect{|tax| "^#{tax}"}, :key => 1, :fields => 4
  entrez_synonyms.key_field = "Entrez Gene ID"
  entrez_synonyms.fields = ["Entrez Gene Name Synonyms"]

  identifiers.attach entrez_synonyms

  File.open(t.name, 'w') do |f| f.puts identifiers end
end

file 'lexicon' => 'identifiers' do |t|
  Open.write(t.name, TSV.new(t.prerequisites.first).slice(["Associated Gene Name", "Entrez Gene Name Synonyms"]).to_s)
end


file 'protein_identifiers' do |t|
  identifiers = BioMart.tsv($biomart_db, $biomart_ensembl_protein, $biomart_protein_identifiers, [], nil, :namespace => $namespace)
  $biomart_protein_identifiers.each do |name, key, prefix|
    if prefix
      identifiers.process name do |field, key, values| field.each{|v| v.replace "#{prefix}:#{v}"} end
    end
  end

  File.open(t.name, 'w') do |f| f.puts identifiers end
end


file 'gene_transcripts' do |t|
  transcripts = BioMart.tsv($biomart_db, $biomart_ensembl_gene, $biomart_gene_transcript, [], nil, :type => :flat, :namespace => $namespace)

  File.open(t.name, 'w') do |f| f.puts transcripts end
end

file 'transcripts' => 'gene_positions' do |t|
  transcripts = BioMart.tsv($biomart_db, $biomart_ensembl_transcript, $biomart_transcript, [], nil, :type => :list, :namespace => $namespace)
  transcripts.attach TSV.new('gene_positions'), "Chromosome Name"

  File.open(t.name, 'w') do |f| f.puts transcripts end
end

file 'transcript_3utr' do |t|
  utrs = BioMart.tsv($biomart_db, $biomart_ensembl_transcript, $biomart_transcript_3utr, [], nil, :type => :flat, :namespace => $namespace)

  File.open(t.name, 'w') do |f| 
    f.puts "#: :type=:single#cast=to_i"
    f.puts "#Ensembl Transcript ID\t3' UTR Length"
    utrs.each do |seq,trans|
      trans.each do |tran|
        f.puts [tran, seq.length] * "\t"
      end
    end
  end
end


file 'transcript_5utr' do |t|
  utrs = BioMart.tsv($biomart_db, $biomart_ensembl_transcript, $biomart_transcript_5utr, [], nil, :type => :flat, :namespace => $namespace)

  File.open(t.name, 'w') do |f| 
    f.puts "#: :type=:single#cast=to_i"
    f.puts "#Ensembl Transcript ID\t5' UTR Length"
    utrs.each do |seq,trans|
      trans.each do |tran|
        f.puts [tran, seq.length] * "\t"
      end
    end
  end
end

file 'gene_positions' do |t|
  sequences = BioMart.tsv($biomart_db, $biomart_ensembl_gene, $biomart_gene_positions, [])

  File.open(t.name, 'w') do |f| f.puts sequences end
end

file 'gene_sequence' do |t|
  sequences = BioMart.tsv($biomart_db, $biomart_ensembl_gene, $biomart_gene_sequence, [], nil, :type => :flat, :namespace => $namespace)

  File.open(t.name, 'w') do |f| 
    f.puts "#: :type=:single"
    f.puts "#Ensembl Gene ID\tProtein Sequence"
    sequences.each do |seq, genes|
      genes.each do |gene|
        f.write gene 
        f.write "\t" 
        f.write seq
        f.write "\n"
      end
    end
  end
end

file 'protein_sequence' do |t|
  sequences = BioMart.tsv($biomart_db, $biomart_ensembl_protein, $biomart_protein_sequence, [], nil, :type => :flat, :namespace => $namespace)

  File.open(t.name, 'w') do |f| 
    f.puts "#: :type=:single"
    f.puts "#Ensembl Protein ID\tProtein Sequence"
    sequences.each do |seq, genes|
      genes.each do |gene|
        f.write gene 
        f.write "\t" 
        f.write seq
        f.write "\n"
      end
    end
  end

end

file 'exons' => 'gene_positions' do |t|
  exons = BioMart.tsv($biomart_db, $biomart_ensembl_exon, $biomart_exons, [], nil, :merge => false, :type => :list, :namespace => $namespace)
  exons.attach TSV.new('gene_positions'), "Chromosome Name"

  File.open(t.name, 'w') do |f| f.puts exons end
end

file 'transcript_exons' do |t|
  exons = BioMart.tsv($biomart_db, $biomart_ensembl_transcript, $biomart_transcript_exons, [], nil, :keep_empty => true, :namespace => $namespace)

  File.open(t.name, 'w') do |f| f.puts exons end
end

file 'transcript_sequence' do |t|
  sequences = BioMart.tsv($biomart_db, $biomart_ensembl_transcript, $biomart_transcript_sequence, [], nil, :type => :flat, :namespace => $namespace)

  File.open(t.name, 'w') do |f| 
    f.puts "#: :type=:single"
    f.puts "#Ensembl Transcript ID\tProtein Sequence"
    sequences.each do |seq, genes|
      genes.each do |gene|
        f.write gene 
        f.write "\t" 
        f.write seq
        f.write "\n"
      end
    end
  end
end


#{{{ Variations

$biomart_variation_id = ["SNP ID", "refsnp_id"]
$biomart_variation_position = [["Chromosome Name", "chr_name"], ["Chromosome Start", "chrom_start"]]

file 'germline_variations' do |t|
  BioMart.tsv($biomart_db_germline_variation, $biomart_variation_id, $biomart_variation_position, [], nil, :keep_empty => true, :type => :list, :filename => t.name, :namespace => $namespace)
end

file 'somatic_variations' do |t|
  BioMart.tsv($biomart_db_somatic_variation, $biomart_variation_id, $biomart_variation_position, [], nil, :keep_empty => true, :type => :list, :filename => t.name, :namespace => $namespace)
end


# {{{ Other info

file 'gene_pmids' do |t|
  tsv =  Entrez.entrez2pubmed($taxs)
  text = "#: :namespace=#{$namespace}"
  text += "#Entrez Gene ID\tPMID"
  tsv.each do |gene, pmids|
    text << "\n" << gene << "\t" << pmids * "|"
  end
  Open.write(t.name, text)
end

file 'exon_offsets' => %w(exons transcript_exons gene_transcripts transcripts transcript_exons) do |t|
  require 'rbbt/sources/organism/sequence'

  exons = TSV.new('exons', :persistence => true)
  exon_transcripts = TSV.new('transcript_exons', :double, :key => "Ensembl Exon ID", :fields => ["Ensembl Transcript ID"], :merge => true, :persistence => true )
  gene_transcripts = TSV.new('gene_transcripts', :flat, :persistence => true )
  transcript_info = TSV.new('transcripts', :list, :persistence => true )
  transcript_exons = TSV.new('transcript_exons', :double, :fields => ["Ensembl Exon ID","Exon Rank in Transcript"], :persistence => true )


  string = "#: :namespace=#{$namespace}"
  string += "#Ensembl Exon ID\tEnsembl Transcript ID\tOffset\n"
  exons.each do |exon, info|
    gene, start, finish, strand, chr = info

    transcripts = Organism::Hsa.coding_transcripts_for_exon(exon, exon_transcripts, transcript_info)

    transcript_offsets = {}
    transcripts.each do |transcript|
      offset = Organism::Hsa.exon_offset_in_transcript(exon, transcript, exons, transcript_exons)
      transcript_offsets[transcript] = offset unless offset.nil?
    end
    
    string << exon << "\t" << transcript_offsets.keys * "|" << "\t" << transcript_offsets.values * "|" << "\n"
  end

  Open.write(t.name, string)
end

file 'gene_go' do |t|
  goterms = BioMart.tsv($biomart_db, $biomart_ensembl_gene, $biomart_go, [], nil, :type => :double, :namespace => $namespace)

  File.open(t.name, 'w') do |f| f.puts goterms end
end


rule /[a-z]{3}[0-9]{4}\/.*/i do |t|
  t.name =~ /([a-z]{3}[0-9]{4})\/(.*)/i
  archive = $1
  task    = $2
  old_pwd = FileUtils.pwd
  begin
    FileUtils.mkdir archive unless File.exists? archive
    FileUtils.cd File.join(archive)
    BioMart.set_archive archive
    Rake::Task[task].invoke
    BioMart.unset_archive 
  ensure
    FileUtils.cd old_pwd
  end
end
