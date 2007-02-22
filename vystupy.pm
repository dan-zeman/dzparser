package vystupy;
use utf8;
require 5.000;
require Exporter;
use Carp;
use Encode;

@ISA = qw(Exporter);
@EXPORT = qw(vypsat);

#!/usr/bin/perl
# Funkce pro obsluhu výstupů.

our $cislo_instance; # číslo odlišující naše výstupy od stejných výstupů jiných procesů
my %vystupy;
# V následující proměnné si pamatujeme, jestli už jsme správně zapnuli kódování
# pro STDOUT a STDERR.
our $standardni_kodovani_zapnuto;



#------------------------------------------------------------------------------
# Obálka kolem funkce print(). Než ji zavolá, zkontroluje, zda je už otevřen
# výstupní soubor, a případně ho otevře. Ale pokud neběžíme v módu debug, žádné
# soubory na disku se neotvírají a funkce pouze třídí výstup na STDOUT a
# STDERR.
#------------------------------------------------------------------------------
sub vypsat
{
    my $soubor = shift(@_);
    # Zjistit, jestli je takový soubor už otevřen.
    unless($vystupy{$soubor}{otevreno})
    {
        otevrit_vystup($soubor);
    }
    # Za jistých okolností se některé výstupy neposílají do souboru, ale pouze
    # na STDOUT, STDERR, případně úplně do černé díry. Proto následujíc podmínka.
    if($vystupy{$soubor}{psat_do_souboru})
    {
        print $soubor (@_);
    }
    # Pokud se výstupy posílané do tohoto souboru mají kopírovat i na
    # standardní výstup (tj. většinou na obrazovku), udělat to.
    if($vystupy{$soubor}{kopirovat_na_stdout})
    {
        print @_;
    }
    # Pokud se výstupy posílané do tohoto souboru mají kopírovat i na
    # standardní chybový výstup (tj. většinou na obrazovku), udělat to.
    if($vystupy{$soubor}{kopirovat_na_stderr})
    {
        print STDERR @_;
    }
    # Pokud se výstupy posílané do tohoto souboru mají kopírovat i do mailu,
    # kopírovat.
    if($vystupy{$soubor}{kopirovat_do_mailu})
    {
        print MAIL @_;
    }
}



#------------------------------------------------------------------------------
# Otevře výstupní soubor. Zkonstruuje pro něj jedinečné jméno, aby se proces
# nepřetahoval o jeden soubor s jinými procesy.
#------------------------------------------------------------------------------
sub otevrit_vystup
{
    my $soubor = shift;
    # Zapamatovat si, že jsme tento soubor otevřeli.
    $vystupy{$soubor}{otevreno} = 1;
    # V méně ukecaných režimech vynechat některé druhy výstupů.
    if($::konfig{ukecanost}<1 && $soubor eq "prubeh")
    {
        return;
    }
    if($::konfig{ukecanost}<2 && $soubor eq "konfig")
    {
        return;
    }
    if(!$::konfig{testovat} && $soubor eq "vysledky")
    {
        return;
    }
    # Pokud nejsme v ladicím režimu, psát pouze na STDOUT a STDERR.
    if($::konfig{rezim} ne "debug")
    {
        $vystupy{$soubor}{psat_do_souboru} = 0;
        # Natrénovaný model je standardní výstup skriptu train.pl.
        # Analyzovaný text ve formátu CSTS je standardní výstup skriptu parse.pl.
        if($soubor =~ m/^(stat|csts)$/)
        {
            $vystupy{$soubor}{kopirovat_na_stdout} = 1;
        }
        # Vše ostatní je diagnostický výstup.
        else
        {
            $vystupy{$soubor}{kopirovat_na_stderr} = 1;
        }
    }
    else
    {
        $vystupy{$soubor}{psat_do_souboru} = 1;
        # Zjistit, zda už má tento proces přiřazené číslo, pod kterým ukládá své výstupy.
        if($cislo_instance eq "")
        {
            zjistit_cislo_instance();
        }
        # Sestavit jméno souboru.
        my $jmeno = sprintf("$::konfig{prac}/%03d.$soubor", $cislo_instance);
        $vystupy{$soubor}{cesta} = $jmeno;
        # Otevřít soubor pro zápis (mělo by jít o dosud neexistující soubor, ale nekontrolujeme to).
        open($soubor, ">$jmeno") or croak("Nelze otevrit vystupni soubor $jmeno: $!\n");
        # Stanovit pro soubor kódování.
        if($soubor =~ m/^(csts|stat)$/ && $::konfig{kodovani_data} ne "")
        {
            binmode($soubor, ":encoding($::konfig{kodovani_data})");
        }
        elsif($soubor !~ m/^(csts|stat)$/ && $::konfig{kodovani_log} ne "")
        {
            binmode($soubor, ":encoding($::konfig{kodovani_log})");
        }
        else
        {
            binmode($soubor, ":utf8");
        }
        # Zařídit pro tento soubor autoflush mezi každými dvěma perlovými příkazy.
        my $old_fh = select($soubor);
        $| = 1;
        select($old_fh);
        # Má se tento výstup kopírovat i na standardní výstup?
        # Zatím nastaveno natvrdo pro některé identifikátory souborů.
        if(($soubor eq "prubeh" || $soubor eq "vysledky") && !$::konfig{ticho})
        {
            $vystupy{$soubor}{kopirovat_na_stdout} = 1;
        }
    }
    # Některé výstupy se kopírují na standardní výstup, takže potřebujeme zajistit,
    # že standardní výstup má nastavené nějaké kódování. Je jedno, kdy to uděláme,
    # a mělo by se to udělat jenom jednou. Proto to uděláme hned, bez ohledu na to,
    # jestli zrovna tenhle výstup se bude na STDOUT kopírovat. Při výběru kódování
    # pro standardní výstupy zatím vycházíme z toho, že se budou zobrazovat v terminálu.
    # Kdyby měly být přesměrovány do souboru, mohlo by být vhodnější jiné kódování,
    # alespoň ve Windows, ale na to zatím kašleme.
    unless($standardni_kodovani_zapnuto)
    {
        # Zjistit, zda běžíme pod Windows.
        if(-d "C:\\")
        {
            binmode(STDOUT, ":encoding(cp852)");
            binmode(STDERR, ":encoding(cp852)");
        }
        else
        {
            binmode(STDOUT, ":utf8");
            binmode(STDERR, ":utf8");
        }
        $standardni_kodovani_zapnuto = 1;
        # Zařídit autoflush také na STDOUT a STDERR.
        my $old_fh = select(STDOUT);
        $| = 1;
        select(STDERR);
        $| = 1;
        select($old_fh);
    }
}



#------------------------------------------------------------------------------
# Přiřadí běžícímu procesu číslo, pod kterým bude ukládat své výstupy. Není to
# číslo procesu, ale číslo o 1 vyšší než nejvyšší dosud použité kladné číslo ve
# výstupní složce.
#------------------------------------------------------------------------------
sub zjistit_cislo_instance
{
    return if($cislo_instance ne "");
    # Projít výstupní složku, vybrat soubory, jejichž jméno začíná číslem a
    # tečkou, a zjistit nejvyšší takové číslo.
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
# Zařídit, aby se kopie výstupu poslala někam mailem. Neumím zařídit, aby to
# šlo provést kdykoli a aby se již vypsaný text zkopíroval. V mailu se tedy
# objeví pouze text, který byl poslán na výstup až po zavolání této funkce!
# Pozor, v jednu chvíli se může do mailu kopírovat jen jeden výstup. Při novém
# volání funkce kopirovat_do_mailu() by se měl starý mail ihned odeslat a další
# výstupy se stejným identifikátorem už se do něj nedostanou!
#------------------------------------------------------------------------------
sub kopirovat_do_mailu
{
    my $sendmail = "/usr/sbin/sendmail";
    my $soubor = shift;
    my $predmet = shift;
    # Otevřít mail. Pokud to nejde, rovnou skončit.
    if(-f $sendmail)
    {
        # Zjistit, jestli je takový soubor už otevřen.
        my $byl_uz_otevren = 1;
        unless($vystupy{$soubor}{otevreno})
        {
            $byl_uz_otevren = 0;
            otevrit_vystup($soubor);
        }
        $vystupy{$soubor}{kopirovat_do_mailu} = 1;
        # Otevřít mail a vypsat jeho záhlaví.
        open(MAIL, "|$sendmail zeman\@ufal.mff.cuni.cz");
        binmode(MAIL, ":utf8");
        print MAIL ("From: Parser <zeman\@ufal.mff.cuni.cz>\n");
        print MAIL ("To: Daniel Zeman <zeman\@ufal.mff.cuni.cz>\n");
        print MAIL ("Subject: $predmet\n");
        print MAIL ("Content-type: text/plain; charset=utf-8\n");
        print MAIL ("Content-transfer-encoding: 8bit\n");
        print MAIL ("\n");
    }
}



# Aby to fungovalo, musí modul vrátit pravdu.
1;
