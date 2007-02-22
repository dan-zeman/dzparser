package vystupy;
require 5.000;
require Exporter;
use Carp;
use Encode;

@ISA = qw(Exporter);
@EXPORT = qw(vypsat);

#!/usr/bin/perl
# Funkce pro obsluhu výstupù.

our $cislo_instance; # èíslo odli¹ující na¹e výstupy od stejných výstupù jiných procesù
my %otevrene_vystupy;
my %parametry_vystupu;
my %kodovani; # pro ka¾dý výstup identifikace kódování, které se má pou¾ít pøi pøípadném kopírování tohoto výstupu na STDOUT
# Jestli¾e má výstup v okam¾iku zavírání nastavený subject, po¹le se kopie výstupu na zeman@ufal.mff.cuni.cz s tímto pøedmìtem.
our %subject;



#------------------------------------------------------------------------------
# Obálka kolem funkce print(). Ne¾ ji zavolá, zkontroluje, zda je u¾ otevøen
# výstupní soubor, a pøípadnì ho otevøe.
#------------------------------------------------------------------------------
sub vypsat
{
    my $soubor = shift(@_);
    # Zjistit, jestli je takový soubor u¾ otevøen.
    if(!exists($otevrene_vystupy{$soubor}))
    {
        otevrit_vystup($soubor);
    }
    # Nyní do souboru vypsat po¾adovaný text.
    print $soubor @_;
    # Pokud se výstupy posílané do tohoto souboru mají kopírovat i na
    # standardní výstup (tj. vìt¹inou na obrazovku), a pokud tato funkce
    # není globálnì zablokovaná (napø. proto¾e bì¾íme na pozadí), udìlat to.
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
    # Pokud se výstupy posílané do tohoto souboru mají kopírovat i do mailu,
    # kopírovat.
    if(exists($subject{$soubor}))
    {
        print MAIL @_;
    }
}



#------------------------------------------------------------------------------
# Otevøe výstupní soubor. Zkonstruuje pro nìj jedineèné jméno, aby se proces
# nepøetahoval o jeden soubor s jinými procesy.
#------------------------------------------------------------------------------
sub otevrit_vystup
{
    my $soubor = $_[0];
    # Zjistit, zda u¾ má tento proces pøiøazené èíslo, pod kterým ukládá své výstupy.
    if($cislo_instance eq "")
    {
        zjistit_cislo_instance();
    }
    # Sestavit jméno souboru.
    my $jmeno = sprintf("$::konfig{prac}/%03d.$soubor", $cislo_instance);
    # Otevøít soubor pro zápis (mìlo by jít o dosud neexistující soubor, ale nekontrolujeme to).
    open($soubor, ">$jmeno")
        or croak("Nelze otevrit vystupni soubor $jmeno: $!\n");
    # Zaøídit pro tento soubor autoflush mezi ka¾dými dvìma perlovými pøíkazy.
    my $old_fh = select($soubor);
    $| = 1;
    select($old_fh);
    # Zapamatovat si, ¾e jsme tento soubor otevøeli.
    $otevrene_vystupy{$soubor} = $jmeno;
    # Má se tento výstup kopírovat i na standardní výstup?
    # Zatím nastaveno natvrdo pro nìkteré identifikátory souborù.
    if($soubor eq "prubeh" || $soubor eq "vysledky")
    {
        $parametry_vystupu{$soubor} = "copy-to-stdout";
        # Zaøídit autoflush také na standardním výstupu, kam se prùbì¾nì hlásí stav.
        my $old_fh = select(STDOUT);
        $| = 1;
        select($old_fh);
        # Zajistit správné kódování na standardním výstupu (tato funkce je tu kvùli oknu MS DOS).
        # Primitivní identifikace, ¾e pracujeme v systému postaveném na DOSu: existuje cesta C:\?
        if(-d "C:\\")
        {
            $kodovani{$soubor} = "cp852";
        }
    }
}



#------------------------------------------------------------------------------
# Pøiøadí bì¾ícímu procesu èíslo, pod kterým bude ukládat své výstupy. Není to
# èíslo procesu, ale èíslo o 1 vy¹¹í ne¾ nejvy¹¹í dosud pou¾ité kladné èíslo ve
# výstupní slo¾ce.
#------------------------------------------------------------------------------
sub zjistit_cislo_instance
{
    return if($cislo_instance ne "");
    # Projít výstupní slo¾ku, vybrat soubory, jejich¾ jméno zaèíná èíslem a
    # teèkou, a zjistit nejvy¹¹í takové èíslo.
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
# Zaøídit, aby se kopie výstupu poslala nìkam mailem. Neumím zaøídit, aby to
# ¹lo provést kdykoli a aby se ji¾ vypsaný text zkopíroval. V mailu se tedy
# objeví pouze text, který byl poslán na výstup a¾ po zavolání této funkce!
#------------------------------------------------------------------------------
sub kopirovat_do_mailu
{
    my $sendmail = "/usr/sbin/sendmail";
    my $soubor = $_[0];
    my $predmet = $_[1];
    # Otevøít mail. Pokud to nejde, rovnou skonèit.
    if(-f $sendmail)
    {
        # Zjistit, jestli je takový soubor u¾ otevøen.
        my $byl_uz_otevren = 1;
        if(!exists($otevrene_vystupy{$soubor}))
        {
            $byl_uz_otevren = 0;
            otevrit_vystup($soubor);
        }
        $subject{$soubor} = $predmet;
        # Otevøít mail a vypsat jeho záhlaví.
        open(MAIL, "|$sendmail zeman\@ufal.mff.cuni.cz");
        print MAIL ("From: Parser <zeman\@ufal.mff.cuni.cz>\n");
        print MAIL ("To: Daniel Zeman <zeman\@ufal.mff.cuni.cz>\n");
        print MAIL ("Subject: $predmet\n");
        print MAIL ("Content-type: text/plain; charset=iso-8859-2\n");
        print MAIL ("\n");
    }
}



# Aby to fungovalo, musí modul vrátit pravdu.
1;
