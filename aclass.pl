#!/usr/bin/perl
# Na základě morfologických značek rodiče a dítěte přiřadí syntaktickou značku.
# (c) 2007 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

sub usage
{
    print STDERR ("Usage: aclass.pl -m model [-z mdgdz] < input > output\n");
    print STDERR ("  model:  the output of atrain.pl (trained model)\n");
    print STDERR ("  mdgdz:  read structure from <MDg src=\"dz\">; default <g>\n");
    print STDERR ("  input:  CSTS file to add syntactic tags\n");
    print STDERR ("  output: CSTS file with added syntactic tags\n");
}

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
use Getopt::Long;
use csts;
use lib '/home/zeman/projekty/parser';
use strom;



# Přečíst volby.
# Zdroj: prázdný nebo "rodic_vzor" znamená <g>, jinak třeba "mdgdz" znamená <MDg src="dz">.
GetOptions('model=s' => \$model, 'zdroj=s' => \$zdroj);
if($model eq "")
{
    usage();
    die("Chybí model.\n");
}
# Přečíst statistiku.
open(STAT, $model) or die("Nelze číst $model: $!\n");
while(<STAT>)
{
    # Odstranit znak konce řádku.
    s/\r?\n$//;
    # Rozdělit řádek na klíč (dvojice morfologických značek) a hodnotu (syntaktickou značku).
    my ($klic, $hodnota) = split(/\t/, $_);
    # Uložit do hashe.
    $stat{$klic} = $hodnota;
}
close(STAT);
csts::projit_data("-", \%konfig, \&zpracovat_vetu);
$n_spravne = 0 if($n_spravne eq "");
$n_spatne = $n_celkem-$n_spravne;
$uspesnost = $n_celkem ? $n_spravne/$n_celkem : 0;
print STDERR ("A $n_celkem - G $n_spravne - B $n_spatne - P $uspesnost\n");
print STDERR ("Neznámá dvojice mznaček, ale známá mznačka dítěte: $n_neznama_dvojice        z toho chyb $n_chyb_neznama_dvojice\n");
print STDERR ("Není známa ani mznačka dítěte:                     $n_neznama_dvojice_i_dite z toho chyb $n_chyb_neznama_dvojice_i_dite\n");



#------------------------------------------------------------------------------
# Zpracuje poslední přečtenou větu.
#------------------------------------------------------------------------------
sub zpracovat_vetu
{
    my $stav_cteni = shift; # hash s údaji o aktuálním dokumentu, odstavci a větě
    my $anot = shift; # pole hashů o jednotlivých slovech
    # Postavit si strom podle výstupu parseru.
    strom::postavit($anot, $zdroj);
    # Vypsat začátek věty.
    print("<s>\n");
    # Projít větu po slovech.
    foreach my $slovo (@{$anot})
    {
        my $klic = "$slovo->{znacka} $slovo->{parent}{znacka}";
        # Odstranit z klíče případné tabulátory a konce řádků, protože totéž jsme dělali při tréninku.
        $klic =~ s/[\t\r\n]+/ /sg;
        my $hodnota = $stat{$klic};
        my $neznama_dvojice = 0;
        my $neznama_dvojice_i_dite = 0;
        # Jestliže jsme nenašli žádnou sznačku pro danou dvojici mznaček, zkusíme najít sznačku pro mznačku dítěte.
        if($hodnota eq "")
        {
            $klic = $slovo->{znacka};
            $klic =~ s/[\t\r\n]+/ /sg;
            $hodnota = $stat{$klic};
            $n_neznama_dvojice++;
            $neznama_dvojice = 1;
        }
        # Jestliže jsme ani teď nenašli žádnou sznačku, zkusíme najít nejčastější sznačku.
        if($hodnota eq "")
        {
            $klic = "";
            $hodnota = $stat{$klic};
            $n_neznama_dvojice_i_dite++;
            $neznama_dvojice_i_dite = 1;
        }
        # Zkontrolovat, zda hodnota z naší statistiky odpovídá skutečné syntaktické značce slova.
        $slovo->{afun} =~ s/[\t\r\n]+/ /sg;
        if($hodnota eq $slovo->{afun})
        {
            $n_spravne++;
        }
        else
        {
            if($neznama_dvojice)
            {
                $n_chyb_neznama_dvojice++;
            }
            elsif($neznama_dvojice_i_dite)
            {
                $n_chyb_neznama_dvojice_i_dite++;
            }
        }
        $n_celkem++;
        # Vypsat slovo.
        if($slovo->{ord})
        {
            $slovo->{form} =~ s/&/&amp;/g;
            $slovo->{form} =~ s/</&lt;/g;
            $slovo->{form} =~ s/>/&gt;/g;
            $slovo->{lemma} =~ s/&/&amp;/g;
            $slovo->{lemma} =~ s/</&lt;/g;
            $slovo->{lemma} =~ s/>/&gt;/g;
            $slovo->{znacka} =~ s/&/&amp;/g;
            $slovo->{znacka} =~ s/</&lt;/g;
            $slovo->{znacka} =~ s/>/&gt;/g;
            $hodnota =~ s/&/&amp;/g;
            $hodnota =~ s/</&lt;/g;
            $hodnota =~ s/>/&gt;/g;
            print("<f>$slovo->{form}<l>$slovo->{lemma}<t>$slovo->{znacka}<r>$slovo->{ord}<g>$slovo->{rodic_vzor}<A>$slovo->{afun}<MDg src=\"dz\">$slovo->{mdgdz}<MDA src=\"dz\">$hodnota\n");
        }
    }
}
