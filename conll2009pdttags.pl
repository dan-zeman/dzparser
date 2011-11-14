#!/usr/bin/perl
# Converts part of speech tags and features in CoNLL 2009 Czech file to PDT tags.
# Copyright © 2006, 2009 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
use tagset::en::conll2009;

# Create a hash of all known CoNLL 2009 tags. We will check that only these occur in data.
$list = tagset::en::conll2009::list();
foreach my $tag (@{$list})
{
    $known_tags{$tag}++;
#    print STDERR ("Known tag $tag\n");
}
$i_sentence = 1;
$new_sentence = 1;
while(<>)
{
    # Blank line signals new sentence.
    # Take several consecutive blank lines as one sentence break (avoid empty sentences).
    if(!$new_sentence && m/^\s*$/)
    {
        $i_sentence++;
        $new_sentence = 1;
    }
    # Any non-blank line is a token.
    else
    {
        # If this is the first word of the sentence, print the sentence start tag.
        if($new_sentence)
        {
            $new_sentence = 0;
        }
        # Strip the line break.
        s/\r?\n$//;
        # Get field values and print them.
        my ($id, $form, $lemma, $cpostag, $postag, $feats, $pdttag, $head, $deprel, $plemma, $ppos, $pfeat, $phead, $pdeprel, $fillpred, $pred, @apreds);
        # Warning: the PHEAD and PDEPREL occur in both CoNLL 2009 and 2006 but have totally different meanings!
        # We could call them differently but we do not use their values so far so it does not make a difference.
        ($id, $form, $lemma, $plemma, $postag, $ppos, $feats, $pfeat, $head, $phead, $deprel, $pdeprel, $fillpred, $pred, @apreds) = split(/\s+/, $_);
        my $tag = "$postag\t$feats";
        my $ptag = "$ppos\t$pfeat";
        if(!exists($known_tags{$tag}))
        {
            print STDERR ("$_\n");
            print STDERR ("Warning: Unknown tag $tag\n");
        }
    }
}
