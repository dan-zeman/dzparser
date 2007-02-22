package vystupy;
require 5.000;
require Exporter;
use Carp;
use Encode;

@ISA = qw(Exporter);
@EXPORT = qw(vypsat);

#!/usr/bin/perl
# Funkce pro obsluhu v�stup�.

our $cislo_instance; # ��slo odli�uj�c� na�e v�stupy od stejn�ch v�stup� jin�ch proces�
my %otevrene_vystupy;
my %parametry_vystupu;
my %kodovani; # pro ka�d� v�stup identifikace k�dov�n�, kter� se m� pou��t p�i p��padn�m kop�rov�n� tohoto v�stupu na STDOUT
# Jestli�e m� v�stup v okam�iku zav�r�n� nastaven� subject, po�le se kopie v�stupu na zeman@ufal.mff.cuni.cz s t�mto p�edm�tem.
our %subject;



#------------------------------------------------------------------------------
# Ob�lka kolem funkce print(). Ne� ji zavol�, zkontroluje, zda je u� otev�en
# v�stupn� soubor, a p��padn� ho otev�e.
#------------------------------------------------------------------------------
sub vypsat
{
    my $soubor = shift(@_);
    # Zjistit, jestli je takov� soubor u� otev�en.
    if(!exists($otevrene_vystupy{$soubor}))
    {
        otevrit_vystup($soubor);
    }
    # Nyn� do souboru vypsat po�adovan� text.
    print $soubor @_;
    # Pokud se v�stupy pos�lan� do tohoto souboru maj� kop�rovat i na
    # standardn� v�stup (tj. v�t�inou na obrazovku), a pokud tato funkce
    # nen� glob�ln� zablokovan� (nap�. proto�e b��me na pozad�), ud�lat to.
    if($parametry_vystupu{$soubor} eq "copy-to-stdout" && !$::konfig{ticho})
    {
        if(exists($kodovani{$soubor}))
        {
            print(map{encode($kodovani{$soubor}, decode("iso-8859-2", $_))}(@_));
        }
        else
        {
            print @_;
        }
    }
    # Pokud se v�stupy pos�lan� do tohoto souboru maj� kop�rovat i do mailu,
    # kop�rovat.
    if(exists($subject{$soubor}))
    {
        print MAIL @_;
    }
}



#------------------------------------------------------------------------------
# Otev�e v�stupn� soubor. Zkonstruuje pro n�j jedine�n� jm�no, aby se proces
# nep�etahoval o jeden soubor s jin�mi procesy.
#------------------------------------------------------------------------------
sub otevrit_vystup
{
    my $soubor = $_[0];
    # Zjistit, zda u� m� tento proces p�i�azen� ��slo, pod kter�m ukl�d� sv� v�stupy.
    if($cislo_instance eq "")
    {
        zjistit_cislo_instance();
    }
    # Sestavit jm�no souboru.
    my $jmeno = sprintf("$::konfig{prac}/%03d.$soubor", $cislo_instance);
    # Otev��t soubor pro z�pis (m�lo by j�t o dosud neexistuj�c� soubor, ale nekontrolujeme to).
    open($soubor, ">$jmeno")
        or croak("Nelze otevrit vystupni soubor $jmeno: $!\n");
    # Za��dit pro tento soubor autoflush mezi ka�d�mi dv�ma perlov�mi p��kazy.
    my $old_fh = select($soubor);
    $| = 1;
    select($old_fh);
    # Zapamatovat si, �e jsme tento soubor otev�eli.
    $otevrene_vystupy{$soubor} = $jmeno;
    # M� se tento v�stup kop�rovat i na standardn� v�stup?
    # Zat�m nastaveno natvrdo pro n�kter� identifik�tory soubor�.
    if($soubor eq "prubeh" || $soubor eq "vysledky")
    {
        $parametry_vystupu{$soubor} = "copy-to-stdout";
        # Za��dit autoflush tak� na standardn�m v�stupu, kam se pr�b�n� hl�s� stav.
        my $old_fh = select(STDOUT);
        $| = 1;
        select($old_fh);
        # Zajistit spr�vn� k�dov�n� na standardn�m v�stupu (tato funkce je tu kv�li oknu MS DOS).
        # Primitivn� identifikace, �e pracujeme v syst�mu postaven�m na DOSu: existuje cesta C:\?
        if(-d "C:\\")
        {
            $kodovani{$soubor} = "cp852";
        }
    }
}



#------------------------------------------------------------------------------
# P�i�ad� b��c�mu procesu ��slo, pod kter�m bude ukl�dat sv� v�stupy. Nen� to
# ��slo procesu, ale ��slo o 1 vy��� ne� nejvy��� dosud pou�it� kladn� ��slo ve
# v�stupn� slo�ce.
#------------------------------------------------------------------------------
sub zjistit_cislo_instance
{
    return if($cislo_instance ne "");
    # Proj�t v�stupn� slo�ku, vybrat soubory, jejich� jm�no za��n� ��slem a
    # te�kou, a zjistit nejvy��� takov� ��slo.
    my $max = 0;
    opendir(DIR, $::konfig{prac});
    while($_ = readdir(DIR))
    {
        if(m/^(\d+)\./)
        {
            if($1>$max)
            {
                $max = $1;
            }
        }
    }
    closedir(DIR);
    $cislo_instance = $max+1;
}



#------------------------------------------------------------------------------
# Za��dit, aby se kopie v�stupu poslala n�kam mailem. Neum�m za��dit, aby to
# �lo prov�st kdykoli a aby se ji� vypsan� text zkop�roval. V mailu se tedy
# objev� pouze text, kter� byl posl�n na v�stup a� po zavol�n� t�to funkce!
#------------------------------------------------------------------------------
sub kopirovat_do_mailu
{
    my $sendmail = "/usr/sbin/sendmail";
    my $soubor = $_[0];
    my $predmet = $_[1];
    # Otev��t mail. Pokud to nejde, rovnou skon�it.
    if(-f $sendmail)
    {
        # Zjistit, jestli je takov� soubor u� otev�en.
        my $byl_uz_otevren = 1;
        if(!exists($otevrene_vystupy{$soubor}))
        {
            $byl_uz_otevren = 0;
            otevrit_vystup($soubor);
        }
        $subject{$soubor} = $predmet;
        # Otev��t mail a vypsat jeho z�hlav�.
        open(MAIL, "|$sendmail zeman\@ufal.mff.cuni.cz");
        print MAIL ("From: Parser <zeman\@ufal.mff.cuni.cz>\n");
        print MAIL ("To: Daniel Zeman <zeman\@ufal.mff.cuni.cz>\n");
        print MAIL ("Subject: $predmet\n");
        print MAIL ("Content-type: text/plain; charset=iso-8859-2\n");
        print MAIL ("\n");
    }
}



# Aby to fungovalo, mus� modul vr�tit pravdu.
1;
