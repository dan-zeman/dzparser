#!/usr/bin/perl
# Upraví výstup parseru tak, aby pole, která parser neměl měnit, měla stejnou hodnotu jako na vstupu.
# Jestliže parser neumí zpracovat všechny údaje ze vstupu, neumí je ani zkopírovat na výstup.
# Vyhodnocovací programy by s tím ale mohly mít problém, proto uvedeme výstup parseru do pořádku.
# Copyright © 2009 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

sub usage
{
    print STDERR ("Volání: conll2009merge.pl -i inputfile.conll -s systemoutput.conll > merged.conll\n");
}

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
use Getopt::Long;

GetOptions('inputfile=s' => \$inputfile, 'sysfile=s' => \$sysfile);
if($inputfile eq '')
{
    print STDERR ("Chybí cesta ke vstupnímu souboru.\n");
    usage();
    die();
}
if($sysfile eq '')
{
    print STDERR ("Chybí cesta souboru s výstupem parseru.\n");
    usage();
    die();
}
# Oba soubory budeme číst paralelně a budeme předpokládat, že mají stejný počet vět, řádků a slov.
open(INPUT, $inputfile) or die("Nelze číst ze vstupního souboru $inputfile: $!\n");
open(SYS, $sysfile) or die("Nelze číst ze souboru s výstupem parseru $sysfile: $!\n");
while(<INPUT>)
{
    # Odstranit znak zalomení řádku.
    s/\r?\n$//;
    # Načíst odpovídající řádek výstupního souboru.
    my $sys = <SYS>;
    $sys =~ s/\r?\n$//;
    # Buď je na obou stranách prázdný řádek, nebo je na obou neprázdný.
    if($_ eq '' && $sys ne '')
    {
        die("Prázdnému řádku (zalomení věty) ve vstupním souboru odpovídá neprázdný řádek ve výstupním souboru.\n");
    }
    if($sys eq '' && $_ ne '')
    {
        die("Prázdnému řádku (zalomení věty) ve výstupním souboru odpovídá neprázdný řádek ve vstupním souboru.\n");
    }
    # Prázdný řádek (zalomení věty) prostě opsat a jít dál.
    if($_ eq '')
    {
        print("\n");
    }
    # Vlastní slévání probíhá na neprázdných řádcích, odpovídajících slovům.
    else
    {
        # Rozebrat vstupní i výstupní řádek na jednotlivé atributy.
        my $vstup = radek_na_hash($_);
        my $vystup = radek_na_hash($sys);
        # Pokud nemají slova na obou stranách stejné id (pořadí slova ve větě), něco je špatně.
        if($vstup->{id} != $vystup->{id})
        {
            die("Id vstupního slova ($vstup->{id}) se neshoduje s id výstupního slova ($vystup->{id}).\n");
        }
        # Hodnoty, na které parser neměl sahat, obnovit ve výstupu podle vstupu.
        # Pozor! Přestože organizátoři změnili význam původních polí PHEAD a PDEPREL a označili je nově
        # za pole určená pro výstup parseru, při vyhodnocování nadále očekávají výstup parseru v "ručních" polích HEAD a DEPREL!
        map {$vystup->{$_} = $vstup->{$_}} qw(form lemma plemma pos ppos feat pfeat fillpred);
        # Ostatní hodnoty musí být neprázdné. Pokud jsou prázdné, nahradit je podtržítkem.
        map {$vystup->{$_} = '_' if($vystup->{$_} =~ m/^\s*$/)} qw(head phead deprel pdeprel pred);
        map {$_ = '_' if($_ =~ m/^\s*$/)} @{$vystup->{apreds}};
        # Upravený výstup vypsat.
        my @cells =
        (
            $vystup->{id},
            $vystup->{form},
            $vystup->{lemma},
            $vystup->{plemma},
            $vystup->{pos},
            $vystup->{ppos},
            $vystup->{feat},
            $vystup->{pfeat},
            $vystup->{head},
            $vystup->{phead},
            $vystup->{deprel},
            $vystup->{pdeprel},
            $vystup->{fillpred},
            $vystup->{pred}
        );
        push(@cells, @{$vystup->{apreds}});
        print(join("\t", @cells), "\n");
    }
}
close(INPUT);
close(SYS);



#------------------------------------------------------------------------------
# Převede řádek formátu CoNLL 2009 na hash popisující slovo.
#------------------------------------------------------------------------------
sub radek_na_hash
{
    # Předpokládáme, že řádek už neobsahuje znak konce řádku.
    my $radek = shift;
    my @nazvy = qw(id form lemma plemma pos ppos feat pfeat head phead deprel pdeprel fillpred pred);
    my @hodnoty = split(/\s+/, $radek);
    my %uzel;
    for(my $i = 0; $i<=$#nazvy; $i++)
    {
        $uzel{$nazvy[$i]} = $hodnoty[$i];
    }
    # To, co zbylo, jsou apreds.
    my @apreds = @hodnoty;
    splice(@apreds, 0, scalar(@nazvy));
    $uzel{apreds} = \@apreds;
    return \%uzel;
}
