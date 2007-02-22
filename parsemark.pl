#!/usr/bin/perl

# Syntakticky rozebere text na vstupu. Na rozd�l od parse.pl si k tomu ne�te
# soubor se statistikou, n�br� p�edpokl�d�, �e u� m� statistiky vepsan� p��mo
# v analyzovan�m textu (pomoc� markparse.pl).



$starttime = time();



# Na��st konfiguraci a knihovn� funkce.
do "parslib.pl";



# Za��dit autoflush na standardn�m v�stupu, kam se pr�b�n� hl�s� stav.
my $old_fh = select(STDOUT);
$| = 1;
select($old_fh);



# ��st testovac� v�ty a analyzovat je.

open(ANALYZA, ">".$konfig{prac}."/".$konfig{analyza});
print ANALYZA ("<csts lang=cs><h><source>PDT</source></h><doc file=\"$konfig{analyza}\" id=\"1\"><a><mod>s<txtype>pub<genre>mix<med>nws<temp>1994<authname>y<opus>ln94206<id>3</a><c><p n=\"1\">\n");

@soubory = glob($konfig{"test"});
$maxc_spatne = 0;
$slova[0] = "#";
$hesla[0] = "#";
$znacky[0] = "#";
# Glob�ln� prom�nn� pro jm�no aktu�ln�ho souboru pou��van� v diagnostick�m
# v�stupu. Mus� b�t extra, proto�e existuje posunut�: posledn� v�ta souboru
# se zpracov�v� a� ve chv�li, kdy u� je otev�en dal�� soubor!
$soubor = $soubory[0];
for($isoubor = 0; $isoubor<=$#soubory; $isoubor++)
{
    # M�sto p�vodn�ch soubor�, na kter� se odkazuje konfigurace, mus�me ��st
    # p�ed�v�kan� soubory. P�edpokl�d�me, �e jsou v pracovn� slo�ce.
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
# Analyzuje v�tu.
#------------------------------------------------------------------------------
sub zpracovat_vetu
{
    my($i, $j);
    if(!$vynechat_vetu)
    {
        # P�ed �ten�m nov� v�ty analyzovat tu starou.
        $veta++;
        my ($sek, $min, $hod) = localtime(time());
        printf("%02d:%02d:%02d $soubor Analyzuje se veta $veta ...",
	       $hod, $min, $sek);
        transformovat_koordinace();
        # P�ipravit po��te�n� seznam povolen�ch hran.
        $povol = "";
        for($i = 0; $i<$#slova; $i++)
        {
            $povol = $povol.$i."-".($i+1).",";
            if($i!=0)
            {
                $povol = $povol.($i+1)."-".$i.",";
            }
            # Pro ka�d� uzel nachystat evidenci rozsahu v�ty, kter� pokr�v�
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
        # Ozna�it koncovou interpunkci.
        if($znacky[$#znacky]=~m/^Z/)
        {
            $slova[$#znacky] = $slova[$#znacky]."K";
            $hesla[$#znacky] = $hesla[$#znacky]."K";
            $znacky[$#znacky] = $znacky[$#znacky]."K";
        }
        # Nejd��ve spojit ko�en s koncovou interpunkc�. Zde nepust�me
        # statistiku v�bec ke slovu.
        if($znacky[$#znacky]=~m/^Z/)
        {
            $rodic[$#znacky] = 0;
            $povol =~ s/\d+-$#znacky,//;
	    ($maxc[$#znacky], $maxp[$#znacky])
		= zjistit_pravdepodobnost($#znacky, 0);
            $pord[$#znacky] = ++$pord;
	    # Zhodnotit spr�vnost z�vislosti a vypsat ladic� z�znam.
	    my $hodnoceni = $struktura[$#znacky]==0 ? "spravne" : "spatne";
	    dbglog("Vybrano 0-$#znacky ($slova[0] $slova[$#znacky]) bez pouziti statistiky ($hodnoceni).\n");
        }
	# Sestavit seznam omezen� na p�id�van� z�vislosti. Nap��klad nelze
	# p�eklenout z�vislost� p�edlo�ku, kter� sama je�t� nem� rodi�e. Tento
	# seznam m� p�ednost p�ed seznamem povolen�ch z�vislost�.
	formulovat_zakazy();
        # Dokud existuj� povolen� z�vislosti, proch�zet je a vyb�rat.
        $pstrom = 1;
        splice(@viterbest);
        $viterbest[0] = ulozit_rozpracovane(); # Zalo�it prvn� strom.
        while($povol ne "")
        {
            # Viterbi
            $nvit = $konfig{"viterbi"};
            splice(@viterbi);
            for($ivit = 0; $ivit<=$#viterbest; $ivit++)
            {
                # Hledat nejlep�� z�vislost tak dlouho, dokud nenalezneme
                # z�vislost, kter� povede k dosud nezn�m�mu stromu. Pokud to
                # jde, nal�zt postupn� N takov�ch hran.
                $n_nalezeno = 0;
                obnovit_rozpracovane($viterbest[$ivit]);
		# Zobrazit seznam povolen�ch z�vislost�.
		zrusit_zakaz(".*", ".*", "viterbi");
                while($povol ne "")
                {
                    # Vybrat z povolen�ch z�vislost� tu moment�ln� nejlep��.
                    @povol = split(/,/, $povol);
                    ($rmax, $zmax, $maxc, $maxp) = najit_max_povol();
                    $maxc[$zmax] = $maxc;
                    $maxp[$zmax] = $maxp;
                    $pord[$zmax] = ++$pord; # Po�ad�, kolik�t� byl zvolen.
                    # Aktualizovat prom�nn� popisuj�c� aktu�ln� strukturu.
		    $soused = pridat_zavislost($rmax, $zmax);
		    prehodnotit_zakazy($rmax, $zmax);
		    # Zhodnotit spr�vnost z�vislosti a vypsat ladic� z�znam.
		    my $hodnoceni = $struktura[$zmax]==$rmax ? 
			"spravne" : "spatne";
                    # Zjistit, jestli strom, na kter� nov� z�vislost vede,
                    # u� m�me, nebo je�t� ne.
                    $pstrom *= $maxp;
		    $prave_nalezeny_strom = ulozit_rozpracovane();
                    $existuje = existuje($prave_nalezeny_strom);
                    if(!$existuje)
                    {
                        $viterbi[++$#viterbi] = $prave_nalezeny_strom;
                        last if(++$n_nalezeno>=$nvit);
                    }
                    # Nalezen� z�vislost vede ke zn�m�mu stromu, tak�e
                    # mus�me hledat d�l. P�ipravit se na nov� hled�n�.
                    # Naposledy nalezenou z�vislost zak�zat.
		    pridat_zakaz($rmax, $zmax, "viterbi");
                    $vitpovol = $povol;
                    obnovit_rozpracovane($viterbest[$ivit]);
                    $origpovol = $povol;
                    $povol = $vitpovol;
                }
            }
            # P�e�ije pouze N nejlep��ch strom�.
            @viterbi = sort {$b<=>$a} (@viterbi);
            for($ivit = 0; $ivit<$nvit && $ivit<=$#viterbi; $ivit++)
            {
                obnovit_rozpracovane($viterbi[$ivit]);
                $viterbest[$ivit] = ulozit_rozpracovane();
                ($rodic = join(",", @rodic)) =~ s/-1//g;
            }
        }
        # Vyvolat nejlep�� strom z nejlep��ch.
        obnovit_rozpracovane($viterbi[0]);
        # Spo��tat chyby.
        zkontrolovat_strom();
	# Vypsat v�sledn� strom.
	vypsat_strom();
    }
    # Vymazat prom�nn�, aby bylo mo�n� ��st dal�� v�tu.
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
# Projde z�vislosti, kter� v dan�m okam�iku je povoleno p�idat do stromu, a
# najde tu nejlep��.
#------------------------------------------------------------------------------
sub najit_max_povol
{
    my($v, $i, $j);
    my($r, $z, $hrana, $c, $p);
    my($rmax, $zmax, $maxc, $maxp);
    # Zjistit, zda jsme v minul�m kole nep�ipojovali prvn� ��st koordinace.
    # To bychom v tomto kole byli povinni p�ipojit zbytek.
    if($priste_vybrat_zavislost=~m/^(\d+)-(\d+)$/)
    {
	$r = $1;
	$z = $2;
	# Pro v�echny p��pady ov��it, �e tato z�vislost je povolen�.
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
    # Vybrat moment�ln� nejlep�� z�vislost nebo koordinaci.
    for(; $maxp eq "";)
    {
	for($i = 0; $i<=$#povol; $i++)
	{
	    # P�e��st z�vislost - kandid�ta.
	    $povol[$i] =~ m/(\d+)-(\d+)/;
	    $r = $1;
	    $z = $2;
	    # Pokud je z�vislost na �ern� listin�, vy�adit ji ze sout�e.
	    # �ern� listina $zakaz m� vy��� prioritu ne� $povol.
	    if(je_zakazana($r, $z))
	    {
		next;
	    }
	    # Zjistit pravd�podobnost z�vislosti.
	    ($p, $c) = zjistit_pravdepodobnost($r, $z);
	    # Zjistit, zda pr�v� nalezen� z�vislost m� vy��� preference ne�
	    # nejlep�� dosud evidovan�.
	    if($maxp eq "" || $p>$maxp) # i==0 nefunguje, kvuli $zakaz
	    {
		$maxp = $p;
		$maxc = $c;
		$rmax = $r;
		$zmax = $z;
		$pristemax = "";
	    }
	    # Druh� mo�nost krom� z�vislosti: koordinace mezi $z a n�k�m dal��m
	    # p�es $r.
	    # Proj�t v�echny uzly, kter� le�� na stejnou stranu od $r jako $r
	    # od $z, zjistit mo�nost jejich koordinace se $z p�es $r (povole-
	    # nost druh� hrany v koordinaci, �etnost takov� koordinace a
	    # neobsazenost koordina�n� spojky jinou, vno�enou koordinac�) a
	    # v p��pad� rekordn�ch preferenc� si zapamatovat koordinaci jako
	    # zat�m nejlep��ho kandid�ta.
	    for($j = 1; $j<=$#slova; $j++)
	    {
		if(($z-$r)*($r-$j)>0 &&
		   $udkzz[$j][$z][$r]>$maxc &&
		   je_povolena($r, $j) &&
		   $afun[$r] ne "CoordX")
		{
		    $maxp = $udkzz[$j][$z][$r]; #!!
		    # Vyn�sobit pravd�podobnost koordinace pravd�podobnost�
		    # koordina�n� spojky.
		    $maxp *= $udkjj[$r]/$uduss[$r];
		    $maxc = $maxp;
		    $rmax = $r;
		    $zmax = $z;
		    $pristemax = "$rmax-$j";
		}
	    }
	}
	# Pokud se mezi povolen�mi nena�la jedin� nezak�zan� z�vislost, nouzov�
	# situace: zru�it v�echny z�kazy pro tuto v�tu.
	if($maxp eq "")
	{
	    $zakaz = "";
	}
    }
    # Zv�t�zila-li koordinace, zkop�rovat do koordina�n� spojky zna�ku
    # �lena koordinace.
    if($pristemax ne "")
    {
	$znacky[$rmax] = $znacky[$zmax];
	$afun[$rmax] = "CoordX";
    }
    $priste_vybrat_zavislost = $pristemax;
    return ($rmax, $zmax, $maxc, $maxp);
}



#------------------------------------------------------------------------------
# Projde z�visl� uzly v povolen�ch hran�ch a vybere ten z nich, kter� by se m�l
# zav�ovat nejd��ve.
#------------------------------------------------------------------------------
sub vybrat_zavisly_uzel
{
    my($zmax, $pmax);
    my $i;
    # V�b�r podle relativn� �etnosti hrany v tr�novac�ch datech.
    if($konfig{"vyberzav"} eq "relativni-cetnost")
    {
	# Proj�t povolen� hrany, naj�t tu s nejvy��� relativn� �etnost� a
	# vr�tit jej� z�visl� uzel.
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
    # V�b�r podle m�ry rozhodnutosti lok�ln�ch souboj�.
    elsif($konfig{lokon} &&
	  $konfig{"vyberzav"} eq "lokalni-souboje")
    {
	# Z�skat seznam mo�n�ch z�visl�ch uzl� ze seznamu povolen�ch hran.
	my $povol_z = $povol;
	$povol_z =~ s/\d+-(\d+)/$1/g;
	$povol_z = ",".join(",", sort{$a<=>$b;}(split(/,/, $povol_z))).",";
	while($povol_z =~ s/,(\d+),\1,/,$1,/) {}
	$povol_z =~ m/^,(.*),$/;
	$povol_z = $1;
	my @povol_z = split(/,/, $povol_z);
	# Pro ka�d�ho kandid�ta na z�visl� uzel z�skat v�t�ze konkurzu na
	# ��d�c� uzel a zejm�na s�lu, se kterou ��d�c� vyhr�l. Z�visl� uzel,
	# jeho� ��d�c� vyhr�l s nejv�t�� silou, bude vybr�n.
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
# Zjist� pravd�podobnost z�vislosti ve zvolen�m modelu.
# Vr�t� pravd�podobnost hrany, �etnost hrany a popis hrany (pro lad�c� ��ely).
#------------------------------------------------------------------------------
sub zjistit_pravdepodobnost
{
    my $r = $_[0];
    my $z = $_[1];
    my($smer, $delka);
    my($hrana, $c, $p);
    # T�m�� vylou�it z�vislost �ehokoli na p�edlo�ce, na kter� u� n�co vis�.
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
    # P�e��st �etnost dan� z�vislosti tak, jak byla ulo�ena do dat programem
    # markparse.
    my $c = (1-$ls)*$udozz[$r][$z]+$ls*$udoss[$r][$z];
    # Proto�e zat�m nem�me v datech ulo�en celkov� po�et ud�lost�, polo�it
    # pravd�podobnost rovnu �etnosti. Nebude z intervalu 0-1, ale dokud ji
    # budeme jen porovn�vat s jin�mi takov�mi "pravd�podobnostmi", je to fuk.
    $p = $c;
    return($p, $c);
}



#------------------------------------------------------------------------------
# P�id� do stromu z�vislost a aktualizuje stromov� glob�ln� prom�nn�.
# Vr�t� index nov�ho souseda ��d�c�ho uzlu sm�rem p�es nov� z�visl� uzel.
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
    # Vy�adit z povolen�ch v�echny z�vislosti pr�v� zav�en�ho uzlu.
    $povol =~ s/(\d+)-$z,//g;
    # Vy�adit v�echny z�vislosti, kter� by zp�sobily cyklus.
    for($i = $r; $i!=-1; $i = $rodic[$i])
    {
        for($j = $lspan[$z]; $j<=$rspan[$z]; $j++)
        {
            $povol =~ s/^$j-$i,//;
            $povol =~ s/,$j-$i,/,/;
        }
    }
    # P�idat hrany mezi nov�m ��d�c�m a sousedem.
    # Nep�id�vat takov�, kter� jsme p�ed chv�l� vy�azovali
    # (zav�sily by u� zav�en� nebo by vnesly cyklus).
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
# Odstran� ze stromu z�vislost a aktualizuje stromov� glob�ln� prom�nn�.
# Vr�t� index (staro)nov�ho souseda ��d�c�ho uzlu sm�rem p�es odstran�n�
# z�visl� uzel.
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
	# Zjistit, jestli odpojovan� uzel le�� na trase od rspanu k ��d�c�mu.
	for($i = $rspan[$r]; $i!=$r; $i = $rodic[$i])
	{
	    if($i==$z)
	    {
		# Zjistit nov� rspan ��d�c�ho uzlu.
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
		# Zkop�rovat nov� rspan i do v�ech p�edk� ��d�c�ho uzlu, kte��
		# sd�leli jeho star� rspan.
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
	# Zjistit, jestli odpojovan� uzel le�� na trase od lspanu k ��d�c�mu.
	for($i = $lspan[$r]; $i!=$r; $i = $rodic[$i])
	{
	    if($i==$z)
	    {
		# Zjistit nov� lspan ��d�c�ho uzlu.
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
		# Zkop�rovat nov� lspan i do v�ech p�edk� ��d�c�ho uzlu, kte��
		# sd�leli jeho star� lspan.
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
    # Proj�t odpojenou komponentu a jej� oba sousedy a posb�rat nov� objeven�
    # (�i obnoven�) mo�nosti z�vislost�.
    my $lsk; # Ko�en sousedn� komponenty vlevo.
    my $psk; # Ko�en sousedn� komponenty vpravo.
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
	    # Sou�asn� zak�zat dosud povolen� z�vislosti, kter� p�ekra�uj�
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
	    # Sou�asn� zak�zat dosud povolen� z�vislosti, kter� p�ekra�uj�
	    # odpojenou komponentu zprava.
	    $povol =~ s/^$i-$lsk,//g;
	    $povol =~ s/,$i-$lsk,/,/g;
	}
    }
    dbglog("Zrusena zavislost $r-$z, odted povoleno:\n$povol\n");
    return $soused;
}



#------------------------------------------------------------------------------
# Vyma�e glob�ln� pole popisuj�c� strom (aby v lad�c�ch v�pisech nem�tly prvky
# s indexy p�esahuj�c�mi d�lku nov� v�ty).
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
# P�id� z�vislost na �ernou listinu (resp. p�id� dal�� d�vod, pro� ji tam
# nechat, pokud u� tam je).
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
# Odebere jeden d�vod z�kazu dan� z�vislosti z �ern� listiny. Pokud toto byl
# posledn� d�vod, z�vislost se stane povolenou a je op�t schopna sout�e.
#------------------------------------------------------------------------------
sub zrusit_zakaz
{
    my $r = $_[0];
    my $z = $_[1];
    my $duvod = $_[2];
    $zakaz =~ s/\($r-$z:$duvod\)//g;
}



#------------------------------------------------------------------------------
# Zjist�, zda je z�vislost na �ern� listin� (do�asn� zak�zan�).
#------------------------------------------------------------------------------
sub je_zakazana
{
    my $r = $_[0];
    my $z = $_[1];
    return $zakaz =~ m/\($r-$z:/;
}



#------------------------------------------------------------------------------
# Zjist�, zda je z�vislost na seznamu povolen�ch (nekontroluje sou�asn� seznam
# z�kaz�!)
#------------------------------------------------------------------------------
sub je_povolena
{
    my $r = $_[0];
    my $z = $_[1];
    return $povol =~ m/^$r-$z,/ || $povol =~ m/,$r-$z,/;
}



#------------------------------------------------------------------------------
# Viterbi: ulo�� rozpracovan� strom, aby mohl p�ej�t k jin�mu.
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
# Viterbi: obnov� rozpracovan� strom.
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
# Viterbi: zjist�, zda dan� strom (zak�dovan� do �et�zce) u� zn�me.
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
# Ov��� shodu z�vislost� ve strom� se z�vislostmi ve vzorov�m strom�.
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
    # Aby bylo mo�n� analyzovat chyby, vypsat spr�vn� strom a
    # za n�j strom vytvo�en� parserem (ve form�tu CSTS).
    printf(" %3d %% (%2d/%2d) $slova[1] $slova[2] $slova[3]\n", $uspesnost_strom*100,
	   $spravne_strom, $celkem_strom);
    if($konfig{"debug"}>=2 && $uspesnost_strom<$konfig{"dbg_prah_uspesnosti"})
    {
	$chyba_vztaz = 0;
        vypsat_dvojstrom(@struktura, @rodic);
    }
}



#------------------------------------------------------------------------------
# Vyp�e na v�stup ve form�tu CSTS dva stromy, kter� zav�s� pod jeden ko�en.
# D�ky tomu bude mo�n� si je v prohl�e�i zobrazit vedle sebe a porovn�vat.
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
# Vyp�e v�sledn� strom na standardn� v�stup.
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
# P�evede koordinace do tvaru vhodn�j��ho pro syntaktickou anal�zu: hlavou nen�
# spojka, ale posledn� �len koordinace.
#------------------------------------------------------------------------------
sub transformovat_koordinace
{
    # Proch�zet seznam uzl� odzadu. Hledat posledn� �len koordinace.
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
            # Prvn� zp�sob transformace. Koordina�n� spojka a posledn� �len se
            # vym�n�, ostatn� z�stanou (tj. vis� nyn� na posledn�m �lenu).
            if($konfig{"transkoord"}==1)
            {
                # Naj�t v�echny jej� dal�� �leny koordinace a pov�sit je
                # do �et�zku pod posledn�ho �lena. Obdobn� spojku a ��rky.
                for($j = $i-1; $j>=0; $j--)
                {
                    if($struktura[$j]==$spojka)
                    {
                        $struktura[$j] = $i;
                    }
                }
            }
            # Druh� zp�sob transformace. Ko�enem je posledn� �len, na n�m
            # vis� spojka a p�edposledn� �len. Ka�d� dal�� �len pak vis� na
            # �lenu napravo od n�j i se spojkou, kter� je odd�luje.
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
            # Je�t� proj�t uzly, kter� nejsou �leny koordinace, ale jsou na n�
            # z�visl�, a le�� napravo od posledn�ho �lenu koordinace.
            for($j = $i+1; $j<=$#struktura; $j++)
            {
                if($struktura[$j]==$spojka)
                {
                    $struktura[$j] = $i;
                }
            }
            $afun[$spojka] = "zpracovan� koordinace";
        }
    }
}



#------------------------------------------------------------------------------
# P�evr�t� zav�en� slo�en�ch p�edlo�ek, aby m�l parser v�bec �anci.
#------------------------------------------------------------------------------
sub transformovat_slozene_predlozky
{
    my $i;
    my @n_deti;
    # Proch�zet seznamem uzl�. Najdeme-li p�edlo�ku, na kter� nic nevis�,
    # pod�v�me se na jej� ��d�c� uzel. Pokud je to podstatn� jm�no v p�d�
    # kompatibiln�m s p�edlo�kou, pouze ho s p�edlo�kou prohod�me. Pokud
    # je to taky p�edlo�ka, najdeme mezi jej�mi d�tmi je�t� podstatn� jm�no,
    # z n�j a z osi�el� p�edlo�ky slo��me p�edlo�kovou fr�zi a to cel� vsuneme
    # mezi druhou p�edlo�ku a jej� ��d�c� uzel.
    for($i = 0; $i<=$#struktura; $i++)
    {
        $n_deti[$struktura[$i]]++;
    }
    for($i = 0; $i<=$#struktura; $i++)
    {
        if($znacky[$i]=~m/^R(\d)/ && $n_deti==0)
        {
            my $pad = $1;
            # Prvn� mo�nost: nad p�edlo�kou uzel, kter� pat�� pod n�.
            if($znacky[$struktura[$i]]=~m/^N$pad/)
            {
                my $novy_rodic = $struktura[$struktura[$i]];
                $struktura[$struktura[$i]] = $i;
                $struktura[$i] = $novy_rodic;
            }
            # Druh� mo�nost: uzel, kter� pat�� nad p�edlo�ku, vis� vedle.
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
# Inicializuje seznam z�kaz� na za��tku zpracov�n� v�ty.
# (Jazykov� z�visl� funkce.)
#------------------------------------------------------------------------------
sub formulovat_zakazy
{
    my($i, $j, $k);

    ### �seky mezi ��rkami ###
    # Zapamatovat si rozd�len� v�ty interpunkc� na �seky.
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
    # Zak�zat z�vislosti vedouc� p�es ��rku. Povoleny budou a� po spojen� v�ech
    # mezi��rkov�ch �sek�.
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
	### P�eskakov�n� bezd�tn�ch p�edlo�ek ###
	# Zak�zat z�vislosti, kter� p�eskakuj� p�edlo�ku, je� dosud nem� d�t�.
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
# Zv�� uvoln�n� n�kter�ch z�kaz� na z�klad� naposledy p�idan� z�vislosti.
# (Jazykov� z�visl� funkce.)
#------------------------------------------------------------------------------
sub prehodnotit_zakazy
{
    my $r = $_[0];
    my $z = $_[1];

    ### �seky mezi ��rkami ###
    # Zv��it hotovost �seku, ke kter�mu n�le�� naposledy zav�en� uzel.
    my $hotovost = --$hotovost_useku[$prislusnost_k_useku[$z]];
    # Jestli�e u� jsou hotov� mezi��rkov� �seky, povolit i z�vislosti vedouc�
    # mezi �seky.
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
	### P�eskakov�n� bezd�tn�ch p�edlo�ek ###
	# Zru�it z�kaz z�vislost�, kter� p�eskakuj� p�edlo�ku, je� u� m� d�t�.
	if($znacky[$r] =~ m/^R/)
	{
	    zrusit_zakaz("\\d+", "\\d+", "predlozka $r");
	}
	# Teoreticky se m��e st�t, �e na ka�d�m konci v�ty z�stane jedna
	# bezd�tn� p�edlo�ka a zbytek z�stane mezi nimi uv�zn�n a nebude se
	# moci p�ipojit ani na jednu stranu. Proto ve chv�li, kdy zb�v�
	# zav�sit posledn� uzel, uvolnit v�echny z�kazy.
	if($pord == $#slova-1)
	{
	    zrusit_zakaz("\\d+", "\\d+", "predlozka \\d+");
	}
    }
}



#------------------------------------------------------------------------------
# Vyp�e lad�c� informaci do souboru DBGLOG, jestli�e je vypisov�n� zapnuto.
#------------------------------------------------------------------------------
sub dbglog
{
    if($dbglog)
    {
	my $retezec = $_[0];
	print DBGLOG ($retezec);
    }
}
