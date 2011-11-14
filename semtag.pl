#!/usr/bin/perl
# Podle naučené statistiky primitivně doplní do dat ve formátu CoNLL 2009 sémantické rysy PRED a APRED.
# Copyright © 2009 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

sub usage
{
    print STDERR ("Volání: semtag.pl -s statfile.semstat < input.conll > output.conll\n");
}

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
use Getopt::Long;

GetOptions('statfile=s' => \$statfile);
if($statfile eq '')
{
    print STDERR ("Chybí cesta k souboru s natrénovanou statistikou.\n");
    usage();
    die();
}
# Načíst statistiku.
open(STAT, $statfile) or die("Nelze číst ze souboru $statfile: $!\n");
while(<STAT>)
{
    # Odstranit znak zalomení řádku.
    s/\r?\n$//;
    # Zajímají nás pouze řádky začínající na PRED a APRED.
    if(s/^PRED\t//)
    {
        # Pro každé lemma si zapamatovat pouze nejčastější predikát.
        my ($lemma, $pred, $cetnost) = split(/\t/, $_);
        if($cetnost > $predmap{$lemma}{cetnost})
        {
            $predmap{$lemma}{pred} = $pred;
            $predmap{$lemma}{cetnost} = $cetnost;
        }
    }
    elsif(s/^APRED\t//)
    {
        # Pro každou kombinaci rysů si zapamatovat pouze nejčastější značku.
        my ($rysy, $apred, $cetnost) = split(/\t/, $_);
        if($cetnost > $apredmap{$rysy}{cetnost})
        {
            $apredmap{$rysy}{apred} = $apred;
            $apredmap{$rysy}{cetnost} = $cetnost;
        }
    }
    elsif(s/^APRED1\t//)
    {
        # Zapamatovat si nejčastější značku APRED vůbec.
        my ($apred, $cetnost) = split(/\t/, $_);
        if($cetnost > $nejcastejsi_apred_cetnost)
        {
            $nejcastejsi_apred = $apred;
            $nejcastejsi_apred_cetnost = $cetnost;
        }
    }
}
close(STAT);
# Číst vstupní soubor, doplňovat hodnoty PRED a APRED a výsledek posílat na výstup.
$i_sentence = 1;
$new_sentence = 1;
@sentence;
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
        # If this is the first word of the sentence, and there has been a previous sentence, process it.
        if($new_sentence)
        {
            process_sentence(\@sentence) if(@sentence);
            splice(@sentence);
            $new_sentence = 0;
        }
        # Strip the line break.
        s/\r?\n$//;
        # Get field values and print them.
        my ($id, $form, $lemma, $cpostag, $postag, $feats, $pdttag, $head, $deprel, $plemma, $ppos, $pfeat, $phead, $pdeprel, $fillpred, $pred, @apreds);
        my ($tag, $ptag);
        # Warning: the PHEAD and PDEPREL occur in both CoNLL 2009 and 2006 but have totally different meanings!
        # We could call them differently but we do not use their values so far so it does not make a difference.
        my @nazvy = qw(id form lemma plemma pos ppos feat pfeat head phead deprel pdeprel fillpred pred);
        my @hodnoty = split(/\s+/, $_);
        my %uzel;
        # Pro ladící účely si uchováme i celý vstupní řádek.
        $uzel{line} = "$_\n";
        while(my $n = shift(@nazvy))
        {
            $uzel{$n} = shift(@hodnoty);
        }
        # To, co zbylo, jsou apreds.
        $uzel{apreds} = \@hodnoty;
        # Přidat uzel do věty.
        push(@sentence, \%uzel);
    }
}
process_sentence(\@sentence) if(@sentence);
print STDERR ("PRED přiřazován neznámému lemmatu v $n_nezname_lemma případech z $n_pred_celkem.\n");
print STDERR ("PRED přiřazen chybně v $n_chyb_pred případech, z toho $n_chyb_pred_nezname_lemma pro neznámé lemma.\n");
print STDERR ("APRED pozic celkem včetně prázdných $n_apred_celkem.\n");
print STDERR ("APRED přiřazen správně v $n_apred_spravne případech.\n");
print STDERR ("APRED měl být prázdný, ale nebyl v $n_chyb_apred_mel_byt_prazdny případech.\n");
print STDERR ("APRED neměl být prázdný, ale byl v $n_chyb_apred_nemel_byt_prazdny případech.\n");
print STDERR ("APRED zvolena špatná značka v $n_chyb_apred_spatna_znacka případech.\n");
print STDERR ("APRED přiřazován neznámé trojici v $n_neznama_apred_trojice případech.\n");
print STDERR ("APRED přiřazován neznámé dvojici v $n_neznama_apred_dvojice případech.\n");



#------------------------------------------------------------------------------
# Zpracuje větu po jejím načtení. Upravenou větu rovnou vypíše na STDOUT.
# Statistiky si bere z globálních proměnných.
#------------------------------------------------------------------------------
sub process_sentence
{
    my $sentence = shift;
    # Máme-li na vstupu zlatý standard, můžeme si spočítat své chyby.
    # K tomu si ale nejdříve musíme udělat kopii zlatého standardu.
    foreach my $word (@{$sentence})
    {
        $word->{goldpred} = $word->{pred};
        @{$word->{goldapreds}} = @{$word->{apreds}};
    }
    # Projít všechna slova věty.
    my $n_pred = 0;
    for(my $i = 0; $i<=$#{$sentence}; $i++)
    {
        my $word = $sentence->[$i];
        # Kontrola mých předpokladů: id uzlu by mělo vždy být o 1 vyšší než jeho pořadí ve větě.
        if($word->{id} != $i+1)
        {
            print STDERR ("Porušen předpoklad, že id ($word->{id}) je o 1 vyšší než index slova ve větě ($i).\n");
            foreach my $word (@{$sentence})
            {
                print($word->{line});
            }
            die;
        }
        # Jestliže je toto slovo považováno za predikát, doplnit jeho identifikátor.
        if($word->{fillpred} eq 'Y')
        {
            if(exists($predmap{$word->{lemma}}))
            {
                $word->{pred} = $predmap{$word->{lemma}}{pred};
                if($word->{pred} ne $word->{goldpred})
                {
                    $n_chyb_pred++;
                }
            }
            else
            {
                $n_nezname_lemma++;
                $word->{pred} = $word->{lemma};
                if($word->{pred} ne $word->{goldpred})
                {
                    $n_chyb_pred_nezname_lemma++;
                    $n_chyb_pred++;
                }
            }
            # Zapamatovat si, o kolikátý predikát jde. Podle toho později zjistíme sloupec pro APRED u závislých uzlů.
            # (Budeme si to pamatovat jako index pole, tedy od 0.)
            $word->{ipred} = $n_pred;
            $n_pred++;
            $n_pred_celkem++;
        }
    }
    $n_apred_celkem += $n_pred * scalar(@{$sentence});
    for my $word (@{$sentence})
    {
        # Jestliže podle mého parseru toto slovo závisí na slovu, které je považováno za predikát, vyplnit do příslušného sloupce APRED.
        my @apreds;
        # Nesmíme dopustit, aby pole @apreds mělo nějaké prvky, jestliže ve větě není žádný predikát.
        if($n_pred>0)
        {
            @apreds = map {'_'} (1..$n_pred);
            my $index_rodice = $word->{phead}-1;
            my $rodic = $sentence->[$index_rodice];
            if($rodic->{fillpred})
            {
                my $apred;
                my $rysy = "$word->{pos}|$rodic->{lemma}|";
                if(exists($apredmap{$rysy.'1'}))
                {
                    $apred = $apredmap{$rysy.'1'}{apred};
                }
                elsif(exists($apredmap{$rysy}))
                {
                    $apred = $apredmap{$rysy}{apred};
                    $n_neznama_apred_trojice++;
                }
                else
                {
                    $apred = $nejcastejsi_apred;
                    $n_neznama_apred_dvojice++;
                }
                $apreds[$rodic->{ipred}] = $apred;
            }
            # Vyhodnocení.
            for(my $i = 0; $i<=$#{$word->{goldapreds}}; $i++)
            {
                my $gold = $word->{goldapreds}[$i];
                if($i==$rodic->{ipred})
                {
                    if($gold eq '_')
                    {
                        $n_chyb_apred_mel_byt_prazdny++;
                    }
                    elsif($gold ne $apreds[$i])
                    {
                        $n_chyb_apred_spatna_znacka++;
                    }
                    else
                    {
                        $n_apred_spravne++;
                    }
                }
                elsif($i!=$rodic->{ipred} && $gold ne '_')
                {
                    $n_chyb_apred_nemel_byt_prazdny++;
                }
            }
        }
        $word->{apreds} = \@apreds;
    }
    # Vypsat větu.
    foreach my $word (@{$sentence})
    {
        my @cells =
        (
            $word->{id},
            $word->{form},
            $word->{lemma},
            $word->{plemma},
            $word->{pos},
            $word->{ppos},
            $word->{feat},
            $word->{pfeat},
            $word->{head},
            $word->{phead},
            $word->{deprel},
            $word->{pdeprel},
            $word->{fillpred},
            $word->{pred}
        );
        push(@cells, @{$word->{apreds}});
        # Žádná hodnota nesmí být prázdná. Prázdné hodnoty nahradit podtržítky.
        map {$_ = '_' if(m/^\s*$/)} @cells;
        print(join("\t", @cells), "\n");
    }
    print("\n");
}
