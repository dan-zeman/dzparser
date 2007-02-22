#!/usr/bin/perl

# Syntakticky rozebere text na vstupu. Na rozdíl od parse.pl si k tomu neète
# soubor se statistikou, nýbr¾ pøedpokládá, ¾e u¾ má statistiky vepsané pøímo
# v analyzovaném textu (pomocí markparse.pl).



$starttime = time();



# Naèíst konfiguraci a knihovní funkce.
do "parslib.pl";



# Zaøídit autoflush na standardním výstupu, kam se prùbì¾nì hlásí stav.
my $old_fh = select(STDOUT);
$| = 1;
select($old_fh);



# Èíst testovací vìty a analyzovat je.

open(ANALYZA, ">".$konfig{prac}."/".$konfig{analyza});
print ANALYZA ("<csts lang=cs><h><source>PDT</source></h><doc file=\"$konfig{analyza}\" id=\"1\"><a><mod>s<txtype>pub<genre>mix<med>nws<temp>1994<authname>y<opus>ln94206<id>3</a><c><p n=\"1\">\n");

@soubory = glob($konfig{"test"});
$maxc_spatne = 0;
$slova[0] = "#";
$hesla[0] = "#";
$znacky[0] = "#";
# Globální promìnná pro jméno aktuálního souboru pou¾ívaná v diagnostickém
# výstupu. Musí být extra, proto¾e existuje posunutí: poslední vìta souboru
# se zpracovává a¾ ve chvíli, kdy u¾ je otevøen dal¹í soubor!
$soubor = $soubory[0];
for($isoubor = 0; $isoubor<=$#soubory; $isoubor++)
{
    # Místo pùvodních souborù, na které se odkazuje konfigurace, musíme èíst
    # pøed¾výkané soubory. Pøedpokládáme, ¾e jsou v pracovní slo¾ce.
    my $soubor = $soubory[$isoubor];
    $soubor =~ s/^.*[\/\\]//;
    $soubor = $konfig{prac}."/".$soubor;
    open(SOUBOR, $soubor);
    while(<SOUBOR>)
    {
        if(m/^<s/ && $ord>0)
        {
            zpracovat_vetu();
	    $soubor = $soubory[$isoubor];
        }
        elsif(m/^<[fd][ >]/)
        {
            zpracovat_slovo();
        }
    }
    close(SOUBOR);
}
if($ord>0)
{
    zpracovat_vetu();
}

print ANALYZA ("</c></doc></csts>\n");
close(ANALYZA);



$g = $spravne;
$b = $spatne;
$n = $spravne+$spatne;
$p = $g/$n unless $n==0;
$g0 = $vynechano_spravne;
$b0 = $vynechano_spatne;
$n0 = $g0+$b0;
$p0 = $g0/$n0 unless $n0==0;
$g1 = $nejiste_spravne;
$b1 = $nejiste_spatne;
$n1 = $g1+$b1;
$p1 = $g1/$n1 unless $n1==0;
$g5 = $jiste_spravne;
$b5 = $jiste_spatne;
$n5 = $g5+$b5;
$p5 = $g5/$n5 unless $n5==0;
print("A $n - G $g - B $b - P $p (vse)\n");
print("A $n5 - G $g5 - B $b5 - P $p5 (>=5)\n");
print("A $n1 - G $g1 - B $b1 - P $p1 (>=1)\n");
print("A $n0 - G $g0 - B $b0 - P $p0 (==0)\n");
print("vztazne: G $spravne_vztaz - B ".($celkem_vztaz-$spravne_vztaz)." - P ".($spravne_vztaz/$celkem_vztaz)."\n") if($celkem_vztaz>0);
$gv = $vyber_spravne;
$bv = $vyber_spatne;
$nv = $gv+$bv;
$pv = $gv/$nv unless $nv==0;
print("A $nv - G $gv - B $bv - P $pv ($konfig{testafun})\n");
print("LKG $lk_zlepseni - LKB $lk_zhorseni\n");

$stoptime = time();
$cas = $stoptime-$starttime;
$hod = int($cas/3600);
$min = int(($cas%3600)/60);
$sek = $cas%60;
printf("Program bezel %02d:%02d:%02d hodin.\n", $hod, $min, $sek);



###############################################################################
# Podprogramy
###############################################################################



#------------------------------------------------------------------------------
# Analyzuje vìtu.
#------------------------------------------------------------------------------
sub zpracovat_vetu
{
    my($i, $j);
    if(!$vynechat_vetu)
    {
        # Pøed ètením nové vìty analyzovat tu starou.
        $veta++;
        my ($sek, $min, $hod) = localtime(time());
        printf("%02d:%02d:%02d $soubor Analyzuje se veta $veta ...",
	       $hod, $min, $sek);
        transformovat_koordinace();
        # Pøipravit poèáteèní seznam povolených hran.
        $povol = "";
        for($i = 0; $i<$#slova; $i++)
        {
            $povol = $povol.$i."-".($i+1).",";
            if($i!=0)
            {
                $povol = $povol.($i+1)."-".$i.",";
            }
            # Pro ka¾dý uzel nachystat evidenci rozsahu vìty, který pokrývá
            # jeho podstrom.
            $lspan[$i] = $i;
            $rspan[$i] = $i;
            $rodic[$i] = -1;
        }
        $lspan[$#slova] = $#slova;
        $rspan[$#slova] = $#slova;
        $rodic[$#slova] = -1;
        $#ndeti = -1;
        for($i = 0; $i<=$#slova; $i++)
        {
            $ndeti[$i] = 0;
        }
        # Oznaèit koncovou interpunkci.
        if($znacky[$#znacky]=~m/^Z/)
        {
            $slova[$#znacky] = $slova[$#znacky]."K";
            $hesla[$#znacky] = $hesla[$#znacky]."K";
            $znacky[$#znacky] = $znacky[$#znacky]."K";
        }
        # Nejdøíve spojit koøen s koncovou interpunkcí. Zde nepustíme
        # statistiku vùbec ke slovu.
        if($znacky[$#znacky]=~m/^Z/)
        {
            $rodic[$#znacky] = 0;
            $povol =~ s/\d+-$#znacky,//;
	    ($maxc[$#znacky], $maxp[$#znacky])
		= zjistit_pravdepodobnost($#znacky, 0);
            $pord[$#znacky] = ++$pord;
	    # Zhodnotit správnost závislosti a vypsat ladicí záznam.
	    my $hodnoceni = $struktura[$#znacky]==0 ? "spravne" : "spatne";
	    dbglog("Vybrano 0-$#znacky ($slova[0] $slova[$#znacky]) bez pouziti statistiky ($hodnoceni).\n");
        }
	# Sestavit seznam omezení na pøidávané závislosti. Napøíklad nelze
	# pøeklenout závislostí pøedlo¾ku, která sama je¹tì nemá rodièe. Tento
	# seznam má pøednost pøed seznamem povolených závislostí.
	formulovat_zakazy();
        # Dokud existují povolené závislosti, procházet je a vybírat.
        $pstrom = 1;
        splice(@viterbest);
        $viterbest[0] = ulozit_rozpracovane(); # Zalo¾it první strom.
        while($povol ne "")
        {
            # Viterbi
            $nvit = $konfig{"viterbi"};
            splice(@viterbi);
            for($ivit = 0; $ivit<=$#viterbest; $ivit++)
            {
                # Hledat nejlep¹í závislost tak dlouho, dokud nenalezneme
                # závislost, která povede k dosud neznámému stromu. Pokud to
                # jde, nalézt postupnì N takových hran.
                $n_nalezeno = 0;
                obnovit_rozpracovane($viterbest[$ivit]);
		# Zobrazit seznam povolených závislostí.
		zrusit_zakaz(".*", ".*", "viterbi");
                while($povol ne "")
                {
                    # Vybrat z povolených závislostí tu momentálnì nejlep¹í.
                    @povol = split(/,/, $povol);
                    ($rmax, $zmax, $maxc, $maxp) = najit_max_povol();
                    $maxc[$zmax] = $maxc;
                    $maxp[$zmax] = $maxp;
                    $pord[$zmax] = ++$pord; # Poøadí, kolikátý byl zvolen.
                    # Aktualizovat promìnné popisující aktuální strukturu.
		    $soused = pridat_zavislost($rmax, $zmax);
		    prehodnotit_zakazy($rmax, $zmax);
		    # Zhodnotit správnost závislosti a vypsat ladicí záznam.
		    my $hodnoceni = $struktura[$zmax]==$rmax ? 
			"spravne" : "spatne";
                    # Zjistit, jestli strom, na který nová závislost vede,
                    # u¾ máme, nebo je¹tì ne.
                    $pstrom *= $maxp;
		    $prave_nalezeny_strom = ulozit_rozpracovane();
                    $existuje = existuje($prave_nalezeny_strom);
                    if(!$existuje)
                    {
                        $viterbi[++$#viterbi] = $prave_nalezeny_strom;
                        last if(++$n_nalezeno>=$nvit);
                    }
                    # Nalezená závislost vede ke známému stromu, tak¾e
                    # musíme hledat dál. Pøipravit se na nové hledání.
                    # Naposledy nalezenou závislost zakázat.
		    pridat_zakaz($rmax, $zmax, "viterbi");
                    $vitpovol = $povol;
                    obnovit_rozpracovane($viterbest[$ivit]);
                    $origpovol = $povol;
                    $povol = $vitpovol;
                }
            }
            # Pøe¾ije pouze N nejlep¹ích stromù.
            @viterbi = sort {$b<=>$a} (@viterbi);
            for($ivit = 0; $ivit<$nvit && $ivit<=$#viterbi; $ivit++)
            {
                obnovit_rozpracovane($viterbi[$ivit]);
                $viterbest[$ivit] = ulozit_rozpracovane();
                ($rodic = join(",", @rodic)) =~ s/-1//g;
            }
        }
        # Vyvolat nejlep¹í strom z nejlep¹ích.
        obnovit_rozpracovane($viterbi[0]);
        # Spoèítat chyby.
        zkontrolovat_strom();
	# Vypsat výsledný strom.
	vypsat_strom();
    }
    # Vymazat promìnné, aby bylo mo¾né èíst dal¹í vìtu.
    vymazat_vetu();
    vymazat_strom();
    $spravne_strom = 0;
    $spatne_strom = 0;
    splice(@viterbest);
    splice(@maxc);
    splice(@maxp);
    splice(@pord);
    $pord = 0;
    $valencni = "";
}



#------------------------------------------------------------------------------
# Projde závislosti, které v daném okam¾iku je povoleno pøidat do stromu, a
# najde tu nejlep¹í.
#------------------------------------------------------------------------------
sub najit_max_povol
{
    my($v, $i, $j);
    my($r, $z, $hrana, $c, $p);
    my($rmax, $zmax, $maxc, $maxp);
    # Zjistit, zda jsme v minulém kole nepøipojovali první èást koordinace.
    # To bychom v tomto kole byli povinni pøipojit zbytek.
    if($priste_vybrat_zavislost=~m/^(\d+)-(\d+)$/)
    {
	$r = $1;
	$z = $2;
	# Pro v¹echny pøípady ovìøit, ¾e tato závislost je povolená.
	if($povol!~m/^$priste_vybrat_zavislost,/ &&
	   $povol!~m/,$priste_vybrat_zavislost,/)
	{
	    print("Pozadovano povinne pridani zavislosti $priste_vybrat_zavislost.\n");
	    print("Povoleny jsou zavislosti $povol\n");
	    vypsat_dvojstrom(@struktura, @rodic);
	    die("CHYBA! Druha cast koordinace prestala byt po pridani prvni casti povolena.\n");
	}
	$priste_vybrat_zavislost = "";
	return($r, $z, 0, 1);
    }
    # Vybrat momentálnì nejlep¹í závislost nebo koordinaci.
    for(; $maxp eq "";)
    {
	for($i = 0; $i<=$#povol; $i++)
	{
	    # Pøeèíst závislost - kandidáta.
	    $povol[$i] =~ m/(\d+)-(\d+)/;
	    $r = $1;
	    $z = $2;
	    # Pokud je závislost na èerné listinì, vyøadit ji ze soutì¾e.
	    # Èerná listina $zakaz má vy¹¹í prioritu ne¾ $povol.
	    if(je_zakazana($r, $z))
	    {
		next;
	    }
	    # Zjistit pravdìpodobnost závislosti.
	    ($p, $c) = zjistit_pravdepodobnost($r, $z);
	    # Zjistit, zda právì nalezená závislost má vy¹¹í preference ne¾
	    # nejlep¹í dosud evidovaná.
	    if($maxp eq "" || $p>$maxp) # i==0 nefunguje, kvuli $zakaz
	    {
		$maxp = $p;
		$maxc = $c;
		$rmax = $r;
		$zmax = $z;
		$pristemax = "";
	    }
	    # Druhá mo¾nost kromì závislosti: koordinace mezi $z a nìkým dal¹ím
	    # pøes $r.
	    # Projít v¹echny uzly, které le¾í na stejnou stranu od $r jako $r
	    # od $z, zjistit mo¾nost jejich koordinace se $z pøes $r (povole-
	    # nost druhé hrany v koordinaci, èetnost takové koordinace a
	    # neobsazenost koordinaèní spojky jinou, vnoøenou koordinací) a
	    # v pøípadì rekordních preferencí si zapamatovat koordinaci jako
	    # zatím nejlep¹ího kandidáta.
	    for($j = 1; $j<=$#slova; $j++)
	    {
		if(($z-$r)*($r-$j)>0 &&
		   $udkzz[$j][$z][$r]>$maxc &&
		   je_povolena($r, $j) &&
		   $afun[$r] ne "CoordX")
		{
		    $maxp = $udkzz[$j][$z][$r]; #!!
		    # Vynásobit pravdìpodobnost koordinace pravdìpodobností
		    # koordinaèní spojky.
		    $maxp *= $udkjj[$r]/$uduss[$r];
		    $maxc = $maxp;
		    $rmax = $r;
		    $zmax = $z;
		    $pristemax = "$rmax-$j";
		}
	    }
	}
	# Pokud se mezi povolenými nena¹la jediná nezakázaná závislost, nouzová
	# situace: zru¹it v¹echny zákazy pro tuto vìtu.
	if($maxp eq "")
	{
	    $zakaz = "";
	}
    }
    # Zvítìzila-li koordinace, zkopírovat do koordinaèní spojky znaèku
    # èlena koordinace.
    if($pristemax ne "")
    {
	$znacky[$rmax] = $znacky[$zmax];
	$afun[$rmax] = "CoordX";
    }
    $priste_vybrat_zavislost = $pristemax;
    return ($rmax, $zmax, $maxc, $maxp);
}



#------------------------------------------------------------------------------
# Projde závislé uzly v povolených hranách a vybere ten z nich, který by se mìl
# zavì¹ovat nejdøíve.
#------------------------------------------------------------------------------
sub vybrat_zavisly_uzel
{
    my($zmax, $pmax);
    my $i;
    # Výbìr podle relativní èetnosti hrany v trénovacích datech.
    if($konfig{"vyberzav"} eq "relativni-cetnost")
    {
	# Projít povolené hrany, najít tu s nejvy¹¹í relativní èetností a
	# vrátit její závislý uzel.
	for($i = 0; $i<=$#povol; $i++)
	{
	    $povol[$i] =~ m/(\d+)-(\d+)/;
	    my $r = $1;
	    my $z = $2;
	    my($p, $c);
	    ($p, $c) = zjistit_pravdepodobnost($r, $z);
	    my($pk, $ck);
	    $priste = "";
	    ($pk, $ck, $priste) = zjistit_pravdepodobnost_koordinace($r, $z);
	    if($pk>$p)
	    {
		$p = $pk;
		$c = $ck;
	    }
	    else
	    {
		$priste = "";
	    }
	    if($i==0 || $p>$pmax)
	    {
		$pmax = $p;
		$zmax = $z;
	    }
	}
    }
    # Výbìr podle míry rozhodnutosti lokálních soubojù.
    elsif($konfig{lokon} &&
	  $konfig{"vyberzav"} eq "lokalni-souboje")
    {
	# Získat seznam mo¾ných závislých uzlù ze seznamu povolených hran.
	my $povol_z = $povol;
	$povol_z =~ s/\d+-(\d+)/$1/g;
	$povol_z = ",".join(",", sort{$a<=>$b;}(split(/,/, $povol_z))).",";
	while($povol_z =~ s/,(\d+),\1,/,$1,/) {}
	$povol_z =~ m/^,(.*),$/;
	$povol_z = $1;
	my @povol_z = split(/,/, $povol_z);
	# Pro ka¾dého kandidáta na závislý uzel získat vítìze konkurzu na
	# øídící uzel a zejména sílu, se kterou øídící vyhrál. Závislý uzel,
	# jeho¾ øídící vyhrál s nejvìt¹í silou, bude vybrán.
	for($i = 0; $i<=$#povol_z; $i++)
	{
	    my($r, $z, $priste, $sila);
	    ($r, $z, $priste, $sila) = lokalni_konflikty(0, $povol_z[$i]);
	    if($i==0 || $sila>$pmax)
	    {
		$pmax = $sila;
		$zmax = $povol_z[$i];
	    }
	}
    }
    return $zmax;
}



#------------------------------------------------------------------------------
# Zjistí pravdìpodobnost závislosti ve zvoleném modelu.
# Vrátí pravdìpodobnost hrany, èetnost hrany a popis hrany (pro ladící úèely).
#------------------------------------------------------------------------------
sub zjistit_pravdepodobnost
{
    my $r = $_[0];
    my $z = $_[1];
    my($smer, $delka);
    my($hrana, $c, $p);
    # Témìø vylouèit závislost èehokoli na pøedlo¾ce, na které u¾ nìco visí.
    if($znacky[$r]=~m/^R/)
    {
	my $i;
	for($i = 0; $i<=$#rodic; $i++)
	{
	    if($rodic[$i]==$r)
	    {
		return(0, 0, "$r $z NA PREDLOZCE UZ NECO VISI");
	    }
	}
    }
    # Pøeèíst èetnost dané závislosti tak, jak byla ulo¾ena do dat programem
    # markparse.
    my $c = (1-$ls)*$udozz[$r][$z]+$ls*$udoss[$r][$z];
    # Proto¾e zatím nemáme v datech ulo¾en celkový poèet událostí, polo¾it
    # pravdìpodobnost rovnu èetnosti. Nebude z intervalu 0-1, ale dokud ji
    # budeme jen porovnávat s jinými takovými "pravdìpodobnostmi", je to fuk.
    $p = $c;
    return($p, $c);
}



#------------------------------------------------------------------------------
# Pøidá do stromu závislost a aktualizuje stromové globální promìnné.
# Vrátí index nového souseda øídícího uzlu smìrem pøes nový závislý uzel.
#------------------------------------------------------------------------------
sub pridat_zavislost
{
    my $r = $_[0];
    my $z = $_[1];
    my($i, $j);
    # Aktualizovat @rodic a @ndeti.
    $rodic[$z] = $r;
    $ndeti[$r]++;
    # Aktualizovat @lspan a @rspan.
    my $soused;
    if($r<$z)
    {
	for($i = $r; $i!=-1; $i = $rodic[$i])
	{
	    $rspan[$i] = $rspan[$z];
	}
	$soused = $rspan[$r]+1;
    }
    else
    {
	for($i = $r; $i!=-1; $i = $rodic[$i])
	{
	    $lspan[$i] = $lspan[$z];
	}
	$soused = $lspan[$r]-1;
    }
    # Aktualizovat $povol.
    # Vyøadit z povolených v¹echny závislosti právì zavì¹eného uzlu.
    $povol =~ s/(\d+)-$z,//g;
    # Vyøadit v¹echny závislosti, které by zpùsobily cyklus.
    for($i = $r; $i!=-1; $i = $rodic[$i])
    {
        for($j = $lspan[$z]; $j<=$rspan[$z]; $j++)
        {
            $povol =~ s/^$j-$i,//;
            $povol =~ s/,$j-$i,/,/;
        }
    }
    # Pøidat hrany mezi novým øídícím a sousedem.
    # Nepøidávat takové, které jsme pøed chvílí vyøazovali
    # (zavìsily by u¾ zavì¹ené nebo by vnesly cyklus).
    if($soused>=0 && $soused<=$#slova)
    {
        for($i = $r; $rodic[$i]!=-1; $i = $rodic[$i]) {}
        if($i!=0)
        {
            for($j = $soused; $j!=-1 && $j ne ""; $j = $rodic[$j])
            {
                $povol = $povol.$j."-".$i.",";
            }
        }
        for($i = $soused; $rodic[$i]!=-1; $i = $rodic[$i]) {}
        if($i!=0)
        {
            for($j = $r; $j!=-1 && $j ne ""; $j = $rodic[$j])
            {
                $povol = $povol.$j."-".$i.",";
            }
        }
    }
    dbglog("Pridana zavislost $r-$z, odted povoleno:\n");
    dbglog("$povol\n") unless($povol eq "");
    return $soused;
}



#------------------------------------------------------------------------------
# Odstraní ze stromu závislost a aktualizuje stromové globální promìnné.
# Vrátí index (staro)nového souseda øídícího uzlu smìrem pøes odstranìný
# závislý uzel.
#------------------------------------------------------------------------------
sub zrusit_zavislost
{
    my $z = $_[0];
    my $r = $rodic[$z];
    return -1 if($r==-1);
    my($i, $j, $k);
    # Aktualizovat @lspan a @rspan.
    my $soused;
    if($r<$z)
    {
	my $stary_rspan = $rspan[$r];
	# Zjistit, jestli odpojovaný uzel le¾í na trase od rspanu k øídícímu.
	for($i = $rspan[$r]; $i!=$r; $i = $rodic[$i])
	{
	    if($i==$z)
	    {
		# Zjistit nový rspan øídícího uzlu.
		if($lspan[$z]>$r)
		{
		    for($j = $lspan[$z]-1; $j>=$r; $j--)
		    {
			for($k = $j; $k!=-1; $k = $rodic[$k])
			{
			    if($k==$r)
			    {
				$rspan[$r] = $j;
				goto rspan_nalezen;
			    }
			}
		    }
		  rspan_nalezen:
		}
		else
		{
		    $rspan[$r] = $r;
		}
		# Zkopírovat nový rspan i do v¹ech pøedkù øídícího uzlu, kteøí
		# sdíleli jeho starý rspan.
		for($j = $rodic[$r]; $j!=-1; $j = $rodic[$j])
		{
		    if($rspan[$j]==$stary_rspan)
		    {
			$rspan[$j] = $rspan[$r];
		    }
		    else
		    {
			last;
		    }
		}
	    }
	}
	$soused = $rspan[$r]+1;
    }
    else
    {
	my $stary_lspan = $lspan[$r];
	# Zjistit, jestli odpojovaný uzel le¾í na trase od lspanu k øídícímu.
	for($i = $lspan[$r]; $i!=$r; $i = $rodic[$i])
	{
	    if($i==$z)
	    {
		# Zjistit nový lspan øídícího uzlu.
		if($rspan[$z]<$r)
		{
		    for($j = $rspan[$z]+1; $j<=$r; $j++)
		    {
			for($k = $j; $k!=-1; $k = $rodic[$k])
			{
			    if($k==$r)
			    {
				$lspan[$r] = $j;
				goto lspan_nalezen;
			    }
			}
		    }
		  lspan_nalezen:
		}
		else
		{
		    $lspan[$r] = $r;
		}
		# Zkopírovat nový lspan i do v¹ech pøedkù øídícího uzlu, kteøí
		# sdíleli jeho starý lspan.
		for($j = $rodic[$r]; $j!=-1; $j = $rodic[$j])
		{
		    if($lspan[$j]==$stary_lspan)
		    {
			$lspan[$j] = $lspan[$r];
		    }
		    else
		    {
			last;
		    }
		}
	    }
	}
	$soused = $lspan[$r]-1;
    }
    # Aktualizovat @rodic a @ndeti.
    $rodic[$z] = -1;
    $ndeti[$r]--;
    # Aktualizovat $povol.
    # Projít odpojenou komponentu a její oba sousedy a posbírat novì objevené
    # (èi obnovené) mo¾nosti závislostí.
    my $lsk; # Koøen sousední komponenty vlevo.
    my $psk; # Koøen sousední komponenty vpravo.
    for($i = $lspan[$z]-1; $i>=0 && $rodic[$i]!=-1; $i = $rodic[$i]) {}
    $lsk = $i;
    for($i = $rspan[$z]+1; $i<=$#slova && $rodic[$i]!=-1; $i = $rodic[$i]) {}
    $psk = $i;
    # Pospojovat odpojenou komponentu se sousedem nalevo.
    if($lsk>=0)
    {
	for($i = $lspan[$z]-1; $i!=-1; $i = $rodic[$i])
	{
	    if($povol!~m/^$i-$z,/ && $povol!~m/,$i-$z,/)
	    {
		$povol .= "$i-$z,";
	    }
	    # Souèasnì zakázat dosud povolené závislosti, které pøekraèují
	    # odpojenou komponentu zleva.
	    $povol =~ s/^$i-$psk,//g;
	    $povol =~ s/,$i-$psk,/,/g;
	}
	if($lsk!=0)
	{
	    for($i = $lspan[$z]; $i!=-1; $i = $rodic[$i])
	    {
		if($povol!~m/^$i-$lsk,/ && $povol!~m/,$i-$lsk,/)
		{
		    $povol .= "$i-$lsk,";
		}
	    }
	}
    }
    # Pospojovat odpojenou komponentu se sousedem napravo.
    if($psk<=$#slova)
    {
	if($psk!=0)
	{
	    for($i = $rspan[$z]; $i!=-1; $i = $rodic[$i])
	    {
		if($povol!~m/^$i-$psk,/ && $povol!~m/,$i-$psk,/)
		{
		    $povol .= "$i-$psk,";
		}
	    }
	}
	for($i = $rspan[$z]+1; $i!=-1; $i = $rodic[$i])
	{
	    if($povol!~m/^$i-$z,/ && $povol!~m/,$i-$z,/)
	    {
		$povol .= "$i-$z,";
	    }
	    # Souèasnì zakázat dosud povolené závislosti, které pøekraèují
	    # odpojenou komponentu zprava.
	    $povol =~ s/^$i-$lsk,//g;
	    $povol =~ s/,$i-$lsk,/,/g;
	}
    }
    dbglog("Zrusena zavislost $r-$z, odted povoleno:\n$povol\n");
    return $soused;
}



#------------------------------------------------------------------------------
# Vyma¾e globální pole popisující strom (aby v ladících výpisech nemátly prvky
# s indexy pøesahujícími délku nové vìty).
#------------------------------------------------------------------------------
sub vymazat_strom
{
    splice(@rodic);
    splice(@coord);
    splice(@lspan);
    splice(@rspan);
    $povol = "";
    $zakaz = "";
}



#------------------------------------------------------------------------------
# Pøidá závislost na èernou listinu (resp. pøidá dal¹í dùvod, proè ji tam
# nechat, pokud u¾ tam je).
#------------------------------------------------------------------------------
sub pridat_zakaz
{
    my $r = $_[0];
    my $z = $_[1];
    my $duvod = $_[2];
    if($zakaz !~ m/\($r-$z:$duvod\)/)
    {
	$zakaz .= "($r-$z:$duvod)";
    }
}



#------------------------------------------------------------------------------
# Odebere jeden dùvod zákazu dané závislosti z èerné listiny. Pokud toto byl
# poslední dùvod, závislost se stane povolenou a je opìt schopna soutì¾e.
#------------------------------------------------------------------------------
sub zrusit_zakaz
{
    my $r = $_[0];
    my $z = $_[1];
    my $duvod = $_[2];
    $zakaz =~ s/\($r-$z:$duvod\)//g;
}



#------------------------------------------------------------------------------
# Zjistí, zda je závislost na èerné listinì (doèasnì zakázaná).
#------------------------------------------------------------------------------
sub je_zakazana
{
    my $r = $_[0];
    my $z = $_[1];
    return $zakaz =~ m/\($r-$z:/;
}



#------------------------------------------------------------------------------
# Zjistí, zda je závislost na seznamu povolených (nekontroluje souèasnì seznam
# zákazù!)
#------------------------------------------------------------------------------
sub je_povolena
{
    my $r = $_[0];
    my $z = $_[1];
    return $povol =~ m/^$r-$z,/ || $povol =~ m/,$r-$z,/;
}



#------------------------------------------------------------------------------
# Viterbi: ulo¾í rozpracovaný strom, aby mohl pøejít k jinému.
#------------------------------------------------------------------------------
sub ulozit_rozpracovane
{
    my $rodic = join(",", @rodic);
    my $coord = join(",", @coord);
    my $lspan = join(",", @lspan);
    my $rspan = join(",", @rspan);
    my $ndeti = join(",", @ndeti);
    my $vysledek = "$pstrom;$rodic;$coord;$lspan;$rspan;$ndeti;$povol;$zakaz;$rmax;$zmax;$maxc;$soused";
    return $vysledek;
}



#------------------------------------------------------------------------------
# Viterbi: obnoví rozpracovaný strom.
#------------------------------------------------------------------------------
sub obnovit_rozpracovane
{
    my $rozpracovane = $_[0];
    my $rodic;
    my $coord;
    my $lspan;
    my $rspan;
    my $ndeti;
    ($pstrom, $rodic, $coord, $lspan, $rspan, $ndeti, $povol, $zakaz, $rmax, $zmax, $maxc, $soused) = split(/;/, $rozpracovane);
    @rodic = split(/,/, $rodic);
    @coord = split(/,/, $coord);
    @lspan = split(/,/, $lspan);
    @rspan = split(/,/, $rspan);
    if($konfig{"debug"}>=2 && $konfig{"viterbi"}>1)
    {
        $rodic =~ s/-1//g;
        dbglog("Obnoven strom $rodic\n");
        dbglog("Naposledy pridano $rmax-$zmax s pravdepodobnosti $maxp.\n");
        dbglog("Soucasna pravdepodobnost stromu $pstrom.\n");
    }
}



#------------------------------------------------------------------------------
# Viterbi: zjistí, zda daný strom (zakódovaný do øetìzce) u¾ známe.
#------------------------------------------------------------------------------
sub existuje
{
    my $strom = $_[0];
    my @strom = split(/;/, $strom);
    my $struktura = $strom[1];
    my $i;
    for($i = 0; $i<=$#viterbi; $i++)
    {
        @strom = split(/;/, $viterbi[$i]);
        if($struktura eq $strom[1])
        {
            return 1;
        }
    }
    return 0;
}



#------------------------------------------------------------------------------
# Ovìøí shodu závislostí ve stromì se závislostmi ve vzorovém stromì.
#------------------------------------------------------------------------------
sub zkontrolovat_strom
{
    my $i;
    $spravne_strom = 0;
    $spatne_strom = 0;
    for($i = 1; $i<=$#struktura; $i++)
    {
        if($rodic[$i]==$struktura[$i])
        {
            $spravne++;
            $spravne_strom++;
            if($maxc[$i]>=5)
            {
                $jiste_spravne++;
            }
            elsif($maxc[$i]>0)
            {
                $nejiste_spravne++;
            }
            else
            {
                $vynechano_spravne++;
            }
	    if($afun[$i]=~m/^($konfig{"testafun"})$/)
	    {
		$vyber_spravne++;
	    }
        }
        else
        {
            $spatne++;
            $spatne_strom++;
            if($maxc[$i]>=5)
            {
                $jiste_spatne++;
            }
            elsif($maxc[$i]>0)
            {
                $nejiste_spatne++;
            }
            else
            {
                $vynechano_spatne++;
            }
	    if($afun[$i]=~m/^($konfig{"testafun"})$/)
	    {
		$vyber_spatne++;
	    }
        }
    }
    $celkem_strom = $spravne_strom+$spatne_strom;
    $uspesnost_strom = $spravne_strom/$celkem_strom unless($celkem_strom==0);
    if($uspesnost_strom==1)
    {
	$stovky++;
	if($celkem_strom>$stovky_max)
	{
	    $stovky_max = $celkem_strom;
	}
	$stovky_sum += $celkem_strom;
    }
    # Aby bylo mo¾né analyzovat chyby, vypsat správný strom a
    # za nìj strom vytvoøený parserem (ve formátu CSTS).
    printf(" %3d %% (%2d/%2d) $slova[1] $slova[2] $slova[3]\n", $uspesnost_strom*100,
	   $spravne_strom, $celkem_strom);
    if($konfig{"debug"}>=2 && $uspesnost_strom<$konfig{"dbg_prah_uspesnosti"})
    {
	$chyba_vztaz = 0;
        vypsat_dvojstrom(@struktura, @rodic);
    }
}



#------------------------------------------------------------------------------
# Vypí¹e na výstup ve formátu CSTS dva stromy, které zavìsí pod jeden koøen.
# Díky tomu bude mo¾né si je v prohlí¾eèi zobrazit vedle sebe a porovnávat.
#------------------------------------------------------------------------------
sub vypsat_dvojstrom
{
    return if(!$dbglog);
    my $i;
    print DBGANAL ("<s id=\"$a\">\n");
    for($i = 0; $i<=$#_; $i++)
    {
        if($i==0 || $i==$#_/2+0.5)
        {
            my $uspesnost;
            if($i==0)
            {
                $uspesnost = "VZOR";
            }
            else
            {
                $uspesnost = sprintf("%d/%d=%d%%", $spravne_strom, $celkem_strom, $uspesnost_strom*100);
            }
            print DBGANAL ("<f>$uspesnost<r>".($i+1)."<g>0\n");
        }
        elsif($i<$#_/2)
        {
	    my ($p, $c) = zjistit_pravdepodobnost($_[$i], $i);
	    $p = sprintf("%.3f", -log($p)/log(10)) unless($p==0);
            print DBGANAL ("<f>$slova[$i]<l>$p<t>$znacky[$i]<r>".($i+1)."<g>".($_[$i]+1)."\n");
        }
        else
        {
	    my $p = sprintf("%s: %.3f", $pord[$i-$#_/2-0.5], -log($maxp[$i-$#_/2-0.5])/log(10)) unless($maxp[$i-$#_/2-0.5]==0);
            print DBGANAL ("<f>$slova[$i-$#_/2-0.5]<l>$p<t>$znacky[$i-$#_/2-0.5]<r>".($i+1)."<g>".($_[$i]+$#_/2+1.5)."\n");
        }
    }
}



#------------------------------------------------------------------------------
# Vypí¹e výsledný strom na standardní výstup.
#------------------------------------------------------------------------------
sub vypsat_strom
{
    $sid++;
    print ANALYZA ("<s id=\"$sid\">\n");
    my $i;
    for($i = 1; $i<=$#rodic; $i++)
    {
	print ANALYZA ("<f>$slova[$i]<l>$hesla[$i]<t>$znacky[$i]<r>$i<g>$struktura[$i]<MDg src=\"dz\">$rodic[$i]\n");
    }
}



#------------------------------------------------------------------------------
# Pøevede koordinace do tvaru vhodnìj¹ího pro syntaktickou analýzu: hlavou není
# spojka, ale poslední èlen koordinace.
#------------------------------------------------------------------------------
sub transformovat_koordinace
{
    # Procházet seznam uzlù odzadu. Hledat poslední èlen koordinace.
    my $i;
    my $j;
    for($i = $#struktura; $i>=0; $i--)
    {
        if($afun[$struktura[$i]] =~ m/^Coord/ &&
           $afun[$i] =~ m/_Co$/)
        {
            my $spojka = $struktura[$i];
            $struktura[$i] = $struktura[$spojka];
            $struktura[$spojka] = $i;
            # První zpùsob transformace. Koordinaèní spojka a poslední èlen se
            # vymìní, ostatní zùstanou (tj. visí nyní na posledním èlenu).
            if($konfig{"transkoord"}==1)
            {
                # Najít v¹echny její dal¹í èleny koordinace a povìsit je
                # do øetízku pod posledního èlena. Obdobnì spojku a èárky.
                for($j = $i-1; $j>=0; $j--)
                {
                    if($struktura[$j]==$spojka)
                    {
                        $struktura[$j] = $i;
                    }
                }
            }
            # Druhý zpùsob transformace. Koøenem je poslední èlen, na nìm
            # visí spojka a pøedposlední èlen. Ka¾dý dal¹í èlen pak visí na
            # èlenu napravo od nìj i se spojkou, která je oddìluje.
            elsif($konfig{"transkoord"}==2)
            {
                my $pravy_soused = $i;
                for($j = $i-1; $j>=0; $j--)
                {
                    if($struktura[$j]==$spojka)
                    {
                        if($afun[$j] =~ m/_Co$/)
                        {
                            $struktura[$j] = $pravy_soused;
                            $pravy_soused = $j;
                        }
                        elsif($afun[$j] eq "AuxX")
                        {
                            $struktura[$j] = $pravy_soused;
                        }
                        else
                        {
                            $struktura[$j] = $i;
                        }
                    }
                }
            }
            else
            {
                my $pravy_soused = $spojka;
                for($j = $i-1; $j>=0; $j--)
                {
                    if($struktura[$j]==$spojka)
                    {
                        if($afun[$j] =~ m/_Co$/ ||
                           $afun[$j] eq "AuxX")
                        {
                            $struktura[$j] = $pravy_soused;
                            $pravy_soused = $j;
                        }
                        else
                        {
                            $struktura[$j] = $i;
                        }
                    }
                }
            }
            # Je¹tì projít uzly, které nejsou èleny koordinace, ale jsou na ní
            # závislé, a le¾í napravo od posledního èlenu koordinace.
            for($j = $i+1; $j<=$#struktura; $j++)
            {
                if($struktura[$j]==$spojka)
                {
                    $struktura[$j] = $i;
                }
            }
            $afun[$spojka] = "zpracovaná koordinace";
        }
    }
}



#------------------------------------------------------------------------------
# Pøevrátí zavì¹ení slo¾ených pøedlo¾ek, aby mìl parser vùbec ¹anci.
#------------------------------------------------------------------------------
sub transformovat_slozene_predlozky
{
    my $i;
    my @n_deti;
    # Procházet seznamem uzlù. Najdeme-li pøedlo¾ku, na které nic nevisí,
    # podíváme se na její øídící uzel. Pokud je to podstatné jméno v pádì
    # kompatibilním s pøedlo¾kou, pouze ho s pøedlo¾kou prohodíme. Pokud
    # je to taky pøedlo¾ka, najdeme mezi jejími dìtmi je¹tì podstatné jméno,
    # z nìj a z osiøelé pøedlo¾ky slo¾íme pøedlo¾kovou frázi a to celé vsuneme
    # mezi druhou pøedlo¾ku a její øídící uzel.
    for($i = 0; $i<=$#struktura; $i++)
    {
        $n_deti[$struktura[$i]]++;
    }
    for($i = 0; $i<=$#struktura; $i++)
    {
        if($znacky[$i]=~m/^R(\d)/ && $n_deti==0)
        {
            my $pad = $1;
            # První mo¾nost: nad pøedlo¾kou uzel, který patøí pod ní.
            if($znacky[$struktura[$i]]=~m/^N$pad/)
            {
                my $novy_rodic = $struktura[$struktura[$i]];
                $struktura[$struktura[$i]] = $i;
                $struktura[$i] = $novy_rodic;
            }
            # Druhá mo¾nost: uzel, který patøí nad pøedlo¾ku, visí vedle.
            elsif($znacky[$struktura[$i]]=~m/^R/)
            {
                my $novy_rodic = $struktura[$struktura[$i]];
                my $mezistupen = $i;
                my $j;
                for($j = 0; $j<=$#struktura; $j++)
                {
                    if($struktura[$j]==$struktura[$i])
                    {
                        $mezistupen = $j;
                        last;
                    }
                }
                $struktura[$struktura[$i]] = $mezistupen;
                $struktura[$mezistupen] = $i;
                $struktura[$i] = $novy_rodic;
            }
        }
    }
}



#------------------------------------------------------------------------------
# Inicializuje seznam zákazù na zaèátku zpracování vìty.
# (Jazykovì závislá funkce.)
#------------------------------------------------------------------------------
sub formulovat_zakazy
{
    my($i, $j, $k);

    ### Úseky mezi èárkami ###
    # Zapamatovat si rozdìlení vìty interpunkcí na úseky.
    splice(@prislusnost_k_useku);
    splice(@hotovost_useku);
    my $i_usek = -1;
    my $carka = 0;
    my $je_co_zakazovat = 0;
    for($i = 0; $i<=$#slova; $i++)
    {
	if($i==0 || $slova[$i] eq "," || $i==$#slova && $znacky[$i]=~m/^Z/)
	{
	    $i_usek++;
	    $carka = 1;
	    $hotovost_useku[$i_usek] = 1;
	}
	elsif($carka)
	{
	    $i_usek++;
	    $carka = 0;
	    $hotovost_useku[$i_usek] = 1;
	}
	else
	{
	    $hotovost_useku[$i_usek]++;
	    $je_co_zakazovat = 1;
	}
	$prislusnost_k_useku[$i] = $i_usek;
    }
    # Zakázat závislosti vedoucí pøes èárku. Povoleny budou a¾ po spojení v¹ech
    # mezièárkových úsekù.
    if($je_co_zakazovat)
    {
	for($i = 0; $i<=$#slova; $i++)
	{
	    for($j = $i+1; $j<=$#slova; $j++)
	    {
		if($prislusnost_k_useku[$i]!=$prislusnost_k_useku[$j])
		{
		    pridat_zakaz($i, $j, "carky");
		    pridat_zakaz($j, $i, "carky");
		}
	    }
	}
    }

    if($konfig{predlozky})
    {
	### Pøeskakování bezdìtných pøedlo¾ek ###
	# Zakázat závislosti, které pøeskakují pøedlo¾ku, je¾ dosud nemá dítì.
	for($i = 0; $i<=$#slova; $i++)
	{
	    if($znacky[$i] =~ m/^R/)
	    {
		for($j = 0; $j<$i; $j++)
		{
		    for($k = $i+1; $k<=$#slova; $k++)
		    {
			pridat_zakaz($j, $k, "predlozka $i");
			pridat_zakaz($k, $j, "predlozka $i");
		    }
		}
	    }
	}
    }
}



#------------------------------------------------------------------------------
# Zvá¾í uvolnìní nìkterých zákazù na základì naposledy pøidané závislosti.
# (Jazykovì závislá funkce.)
#------------------------------------------------------------------------------
sub prehodnotit_zakazy
{
    my $r = $_[0];
    my $z = $_[1];

    ### Úseky mezi èárkami ###
    # Zvý¹it hotovost úseku, ke kterému nále¾í naposledy zavì¹ený uzel.
    my $hotovost = --$hotovost_useku[$prislusnost_k_useku[$z]];
    # Jestli¾e u¾ jsou hotové mezièárkové úseky, povolit i závislosti vedoucí
    # mezi úseky.
    if($hotovost<=1 && $zakaz =~ m/:carky/)
    {
	for($i = 0; $i <= $#hotovost_useku; $i++)
	{
	    if($hotovost_useku[$i] > 1)
	    {
		goto nektere_useky_jeste_nejsou_hotove;
	    }
	}
	zrusit_zakaz("\\d+", "\\d+", "carky");
      nektere_useky_jeste_nejsou_hotove:
    }

    if($konfig{predlozky})
    {
	### Pøeskakování bezdìtných pøedlo¾ek ###
	# Zru¹it zákaz závislostí, které pøeskakují pøedlo¾ku, je¾ u¾ má dítì.
	if($znacky[$r] =~ m/^R/)
	{
	    zrusit_zakaz("\\d+", "\\d+", "predlozka $r");
	}
	# Teoreticky se mù¾e stát, ¾e na ka¾dém konci vìty zùstane jedna
	# bezdìtná pøedlo¾ka a zbytek zùstane mezi nimi uvìznìn a nebude se
	# moci pøipojit ani na jednu stranu. Proto ve chvíli, kdy zbývá
	# zavìsit poslední uzel, uvolnit v¹echny zákazy.
	if($pord == $#slova-1)
	{
	    zrusit_zakaz("\\d+", "\\d+", "predlozka \\d+");
	}
    }
}



#------------------------------------------------------------------------------
# Vypí¹e ladící informaci do souboru DBGLOG, jestli¾e je vypisování zapnuto.
#------------------------------------------------------------------------------
sub dbglog
{
    if($dbglog)
    {
	my $retezec = $_[0];
	print DBGLOG ($retezec);
    }
}
