#!/usr/bin/perl
# Projde soubor ve formátu CoNLL 2009 a naučí se hodnoty PRED a APRED.
# Copyright © 2009 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

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
# Vypsat závěrečné statistiky.
printf("Total %d words.\n", $stat{nwords});
printf("Fill PRED for %d words (%d %%).\n", $stat{nfillpred}, $stat{nwords}>0 ? $stat{nfillpred}/$stat{nwords}*100+0.5 : 0);
# Spočítat průměrnou míru nejednoznačnosti predu v závislosti na lemmatu.
my $n_lemmas = 0;
my $n_preds = 0;
my $max_preds_lemma = 0;
foreach my $lemma (keys(%{$stat{predmap}}))
{
    my @preds = keys(%{$stat{predmap}{$lemma}});
    my $n_preds_lemma = scalar(@preds);
    if($n_preds_lemma>=$max_preds_lemma)
    {
        $max_preds_lemma = $n_preds_lemma;
        print("MAXPREDSLEMMA $max_preds_lemma $lemma: ", join(', ', @preds), "\n");
    }
    $n_lemmas++;
    $n_preds += $n_preds_lemma;
    # Vypsat natrénovaný model.
    foreach my $pred (@preds)
    {
        print("PRED\t$lemma\t$pred\t$stat{predmap}{$lemma}{$pred}\n");
    }
}
printf("Míra nejednoznačnosti: %d lemmat, %d predikátů, tedy průměrně %f predikátů na lemma.\n", $n_lemmas, $n_preds, $n_lemmas>0 ? $n_preds/$n_lemmas : 0);
printf("Nalezeno celkem %d různých hodnot apredů.\n", scalar(keys(%{$stat{apredmap}})));
printf("Celkem %d neprázdných APRED pozic, z toho %d mělo a %d nemělo závislost na predikátu.\n", $stat{apred_je_hrana}+$stat{apred_neni_hrana}, $stat{apred_je_hrana}, $stat{apred_neni_hrana});
foreach my $n_apreds (sort(keys(%{$stat{n_apreds}})))
{
    printf("U %d slov bylo nalezeno %d neprázdných apredikátů.\n", $stat{n_apreds}{$n_apreds}, $n_apreds);
}
foreach my $rysy (keys(%{$stat{apredmodel}}))
{
    my @apreds = keys(%{$stat{apredmodel}{$rysy}});
    my $n_apreds_rysy = scalar(@apreds);
    $n_rysu++;
    $n_apreds += $n_apreds_rysy;
    # Vypsat natrénovaný model.
    foreach my $apred (@apreds)
    {
        print("APRED\t$rysy\t$apred\t$stat{apredmodel}{$rysy}{$apred}\n");
    }
}
foreach my $apred (keys(%{$stat{apredmap}}))
{
    print("APRED1\t$apred\t$stat{apredmap}{$apred}\n");
}
printf("Míra nejednoznačnosti: %d kombinací rysů, %d apredikátů, tedy průměrně %f apredikátů na kombinaci.\n", $n_rysu, $n_apreds, $n_rysu>0 ? $n_apreds/$n_rysu : 0);



#------------------------------------------------------------------------------
# Zpracuje větu po jejím načtení.
# Větu si přebírá jako parametr, ale statistiky, které se učí, ukládá do
# globálních proměnných.
#------------------------------------------------------------------------------
sub process_sentence
{
    my $sentence = shift;
    my @preds;
    # Projít slova věty a zapamatovat si hodnoty predikátů v závislosti na lemmatech.
    foreach my $word (@{$sentence})
    {
        if($word->{fillpred} eq 'Y')
        {
            $stat{nfillpred}++;
            $stat{predmap}{$word->{lemma}}{$word->{pred}}++;
            # Současně si v samostatném poli uchovat odkazy na predikátové uzly.
            push(@preds, $word);
        }
        $stat{nwords}++;
    }
    # Pozor! Z dat to vypadá, že vztah mezi poli PRED a APRED je jiný, než jsem se původně domníval, a to následující:
    # Každý uzel má tolik sloupců APRED, kolik uzlů v dané větě má hodnotu FILLPRED = "Y". Některé nebo všechny APREDs jsou "_".
    # Není pravda, že neprázdnou (nepodtržítkovou) hodnotu v některém sloupci APRED může mít jen uzel, který má sám FILLPRED = "Y".
    # Často to bývá právě naopak.
    # N-tý sloupec APRED odpovídá vztahu uzlu na daném řádku k n-tému predikátu (uzlu s FILLPRED = "Y") ve větě.
    # Neprázdnou hodnotu APRED typicky najdeme tam, kde daný uzel závisí na daném predikátu.
    # Kvůli efektivním rodičům v koordinacích však nemusí jít o závislost ve smyslu pole HEAD daného uzlu.
    # Ze stejného důvodu někdy navíc může uzel záviset na několika predikátech najednou.
    # Teď už víme, kolik je ve větě predikátů a které uzly to jsou.
    # Můžeme tedy znovu projít všechna slova a budeme vědět, kterému uzlu odpovídá který sloupec APRED.
    foreach my $word (@{$sentence})
    {
        # Jestliže správně chápu formát dat, pole @preds a @apreds by měla mít stejný počet prvků.
        # Varovat, pokud tomu tak někde není.
        my $n_preds = scalar(@preds);
        my $n_apreds = scalar(@{$word->{apreds}});
        if($n_preds != $n_apreds)
        {
            print("VAROVÁNÍ: $n_preds predikátů, ale $n_apreds apredikátů.\n");
            foreach my $word (@{$sentence})
            {
                print($word->{line});
            }
            die;
        }
        # Projít všechny hodnoty APRED.
        for(my $j = 0; $j<=$#{$word->{apreds}}; $j++)
        {
            $apred = $word->{apreds}[$j];
            # Zajímají nás pouze neprázdné hodnoty APRED.
            next if($apred eq '_' || $apred eq '');
            # Zapamatovat si existující hodnoty APRED.
            $stat{apredmap}{$apred}++;
            # Jak moc platí, že mezi predikátem a uzlem, který má pro něj vyplněné apred, vede hrana?
            # (Pravděpodobně to nemusí platit, pokud se efektivní rodič liší od technického rodiče, např. u koordinace.)
            if($word->{head} == $preds[$j]{id})
            {
                $stat{apred_je_hrana}++;
            }
            else
            {
                $stat{apred_neni_hrana}++;
            }
            # Zapamatovat si apred jako funkci následujících rysů:
            # (rysů by se dalo najít více, ale nemám čas implementovat vyhlazování)
            # - morfologická značka uzlu, na jehož řádku apred vyplňujeme
            # - lemma predikátu, kterému odpovídá sloupec
            # - informace, zda uzel bezprostředně závisí na predikátu (při nasazení použiju PHEAD, učím se z HEAD)
            my $uzelmzn = $word->{pos};
            my $predlem = $preds[$j]{lemma};
            my $zavislost = $word->{head} == $preds[$j]{id};
            my $rysy = "$uzelmzn|$predlem|$zavislost";
            $stat{apredmodel}{$rysy}{$apred}++;
        }
        # Zapamatovat si počet neprázdných apredů (typický uzel jich má 0 nebo 1).
        my $n_neprazdnych_apredu = scalar(grep {$_ ne '_' && $_ ne ''} @{$word->{apreds}});
        $stat{n_apreds}{$n_neprazdnych_apredu}++;
    }
}
