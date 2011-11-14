#!perl

# 30.10.2009: Verze ze 14.3.2003 překódována do UTF-8 a přestěhována do složky s DZ Parserem, protože se týká výhradně práce s ním.

# Projde 2 logy, vzájemně v nich porovná řádky začínající "Vybrano".
# Hledá případy, kdy v prvním logu bylo vybráno "spravne" a ve druhem "spatne".
# Zajímají ho pouze případy, kdy uvedený rozdíl je prvním rozdílem ve větě.
# Věty, v nichž k něčemu takovému došlo, vypíše.

# Pomáhá odhalovat příčiny zhoršení analýzy po implementaci něčeho nového.

# Nalezené rozdíly budeme vypisovat ve formátu HTML, aby šly snadno zarovnat
# vedle sebe.
print("<html><head><meta http-equiv=\"content-type\" content=\"text/html; charset=iso-8859-2\"></head><body><table>");
# Jména souborů s logy. Podle konvence první obsahuje původní záznam, druhý po změně.
$jms[0] = $ARGV[0];
$jms[1] = $ARGV[1];
open(SOUBOR0, $jms[0]);
open(SOUBOR1, $jms[1]);
while(!eof(SOUBOR0) && !eof(SOUBOR1))
{
    # Načíst do paměti větu z logu 0.
    while(<SOUBOR0>)
    {
        if(m/^0:/)
        {
            last;
        }
        if(m/^Vybrano/)
        {
            $schranka[0][$n[0]] = $_;
            $n[0]++;
        }
        # Až se najde rozdíl, budeme chtít dohledat i způsob, jakým se o něm rozhodovalo.
        else
        {
            $mezischranka[0][$n[0]] .= $_;
        }
    }
    $pristi[0] = $_;
    # Načíst do paměti větu z logu 1.
    while(<SOUBOR1>)
    {
        if(m/^0:/)
        {
            last;
        }
        if(m/^Vybrano/)
        {
            $schranka[1][$n[1]] = $_;
            $n[1]++;
        }
        # Až se najde rozdíl, budeme chtít dohledat i způsob, jakým se o něm rozhodovalo.
        else
        {
            $mezischranka[1][$n[1]] .= $_;
        }
    }
    $pristi[1] = $_;
    # Porovnat obě věty v paměti.
    for($i=0; $i<=$n[0]; $i++)
    {
        my ($z0, $z1, $ok0, $ok1);
        if($schranka[0][$i] =~ m/^Vybrano (\d+-\d+).*(spravne|spatne)/)
        {
            $z0 = $1;
            $ok0 = $2;
        }
        if($schranka[1][$i] =~ m/^Vybrano (\d+-\d+).*(spravne|spatne)/)
        {
            $z1 = $1;
            $ok1 = $2;
        }
        # Na prvním rozdílu porovnávání věty každopádně končí.
        if($z0 ne $z1)
        {
            # Věta se bude vypisovat, jestliže je 0 správně a 1 špatně.
            if($ok0 eq "spravne" && $ok1 eq "spatne")
            {
                my ($log00, $log01, $log10, $log11);
                # Zjistit, jaká byla v obou parserech pravděpodobnost obou závislostí.
                if($mezischranka[0][$i] =~ m/(Zvažuje se závislost $z0.*?)(c\(.*?p\(\d+ \d+\)=[-\d.e]*)/s)
                {
                    $log00 = "$1<pre>$2</pre>";
                }
                if($mezischranka[0][$i] =~ m/(Zvažuje se závislost $z1.*?)(c\(.*?p\(\d+ \d+\)=[-\d.e]*)/s)
                {
                    $log01 = "$1<pre>$2</pre>";
                }
                if($mezischranka[1][$i] =~ m/(Zvažuje se závislost $z0.*?)(c\(.*?p\(\d+ \d+\)=[-\d.e]*)/s)
                {
                    $log10 = "$1<pre>$2</pre>";
                }
                if($mezischranka[1][$i] =~ m/(Zvažuje se závislost $z1.*?)(c\(.*?p\(\d+ \d+\)=[-\d.e]*)/s)
                {
                    $log11 = "$1<pre>$2</pre>";
                }
                $schranka[0][$i] =~ s/(.*)/<font color=red>TADY<\/font><br>$1<table><tr><td valign=top>$log00<\/td><td valign=top>$log01<\/td><\/tr><\/table>/;
                $schranka[1][$i] =~ s/(.*)/<font color=red>TADY<\/font><br>$1<table><tr><td valign=top>$log10<\/td><td valign=top>$log11<\/td><\/tr><\/table>/;
                for($j=0; $j<=$n[0] || $j<=$n[1]; $j++)
                {
                    print("<tr><td valign=top>$schranka[0][$j]</td><td valign=top>$schranka[1][$j]</td></tr>\n");
                }
            }
            last;
        }
    }
    # Další věta.
    splice(@{$schranka[0]});
    splice(@{$schranka[1]});
    splice(@{$mezischranka[0]});
    splice(@{$mezischranka[1]});
    $schranka[0][0] = $pristi[0];
    $schranka[1][0] = $pristi[1];
    $n[0] = 1;
    $n[1] = 1;
}
close(SOUBOR0);
close(SOUBOR1);
print("</table></body></html>");
