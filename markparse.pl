#!/usr/bin/perl

# Postupn� na�te jednotliv� d�ly natr�novan�ho statistick�ho modelu a ozna��
# slova vstupn�ch dat statistikami umo��uj�c�mi rozhodovat o jejich zav�en�
# v syntaktick� struktu�e v�ty. Vlastn� syntaktickou anal�zu zat�m neprov�d�.
# Rozd�len� statistiky do d�l� sni�uje pam�ovou n�ro�nost, ale zvy�uje n�roky
# na �as.



$starttime = time();



# Na��st konfiguraci a knihovn� funkce.
do "parslib.pl";



# Za��dit autoflush na standardn�m v�stupu, kam se pr�b�n� hl�s� stav.
my $old_fh = select(STDOUT);
$| = 1;
select($old_fh);



# P�e��st z konfigurace v�hy slovn�ho a zna�kov�ho modelu (vlastn� si zde
# z�izujeme zkratky, abychom my ani Perl nemuseli pozd�ji pou��vat dlouhou
# notaci $konfig{ls}.
$ls = $konfig{ls};
$lz = 1-$ls;



# Postupn� ��st natr�novan� ��sti statistick�ho modelu a pro ka�dou z nich
# proj�t analyzovan� vstup a ulo�it do n�j k n�mu se v��c� statistiky.

$maska = $konfig{prac}."/".$konfig{stat}."*";
$maska_perl = $konfig{prac}."/".$konfig{stat}."\\d+";
print("Maska pro soubory se statistikou je $maska.\n");
@statistiky = glob($maska);
print("Nalezeno ".($#statistiky+1)." soubor� odpov�daj�c�ch masce.\n");
for($istat = 0; $istat<=$#statistiky; $istat++)
{
    # Pozor, n�kter� soubory nemusej� poch�zet od d�len�ho tr�ninku!
    # Nem��eme jednodu�e sko�it na dal�� pr�chod cyklem, proto�e prvn� skute�n�
    # pr�chod se chov� trochu jinak ne� ostatn�, a pozn� se podle $istat==0.
    while($statistiky[$istat] !~ m/^$maska_perl$/ && $#statistiky>=0)
    {
	shift(@statistiky);
    }
    $scelkem = cist_statistiku($statistiky[$istat], \%stat);
    # Je-li statistika pr�zdn�, zkusit rovnou dal��.
    next if($scelkem==0);
    # ��st testovac� v�ty a analyzovat je.
    @soubory = glob($konfig{test});
    $maxc_spatne = 0;
    # Nachystat ko�en stromu, pro v�echny v�ty stejn�.
    $slova[0] = "#";
    $hesla[0] = "#";
    $znacky[0] = "#";
    # Glob�ln� prom�nn� se jm�nem aktu�ln�ho souboru se pou��v� p�i vypisov�n�
    # diagnostick�ch informac� o pr�v� zpracov�van�m vstupu.
    $soubor = $soubory[0];
    # Proj�t vstupn� soubory, p�e��st je a zpracovat je.
    for($isoubor = 0; $isoubor<=$#soubory; $isoubor++)
    {
	# Poprv� ��st soubor z m�sta ur�en�ho konfigurac�.
	# Pro druhou a dal�� statistiku ��st u� ulo�en� v�sledky p�edch�zej�c�
	# statistiky. V�sledky se ukl�daj� do soubor� stejn�ho jm�na, ale
	# v pracovn� slo�ce.
	my $vystup = $soubory[$isoubor];
	$vystup =~ s/^.*[\/\\]//;
	$vystup = $konfig{prac}."/".$vystup;
	if($istat==0)
	{
	    open(SOUBOR, $soubory[$isoubor]);
	    # Zkontrolovat, �e nehroz�, �e v�stupem p�ep�eme vstup.
	    if($vystup eq $soubory[$isoubor])
	    {
		die("Nelze pokra�ovat, proto�e v�stupem by se p�epsal ".
		    "vstup.\n");
	    }
	    $ANALYZA = otevrit_csts_pro_zapis($vystup, $isoubor);
	}
	else
	{
	    # Zkop�rovat v�stup p�edch�zej�c� statistiky, aby se kopie dala
	    # pou��t jako nov� vstup, zat�mco v�stup by se u� p�episoval.
	    open(ZDROJ, $vystup);
	    open(CIL, ">${vystup}0");
	    while(<ZDROJ>)
	    {
		print CIL;
	    }
	    close(ZDROJ);
	    close(CIL);
	    open(SOUBOR, "${vystup}0");
	    $ANALYZA = otevrit_csts_pro_zapis($vystup, $isoubor);
	}
	# Zpracovat ��dky aktu�ln�ho vstupn�ho souboru.
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
	# Po p�e�ten� souboru zpracovat posledn� v�tu (po n� nen�sleduje ��dn�
	# dal�� <s>, kter� norm�ln� zpracov�n� v�ty spou�t�).
	if($ord>0)
	{
	    zpracovat_vetu();
	}
	zavrit_csts_pro_zapis($ANALYZA);
	close(SOUBOR);
    }
    # P�ed p�echodem k dal�� statistice vymazat tu sou�asnou.
    undef(%stat);
    undef($veta);
}



# Vypsat �daje o dob� trv�n� programu.
$stoptime = time();
$cas = $stoptime-$starttime;
$hod = int($cas/3600);
$min = int(($cas%3600)/60);
$sek = $cas%60;
printf("Program b�el %02d:%02d:%02d hodin.\n", $hod, $min, $sek);



###############################################################################
# Podprogramy
###############################################################################



#------------------------------------------------------------------------------
# Na�te statistick� model z�vislost� na ur�it�ch datech (nap�. na zna�k�ch).
#------------------------------------------------------------------------------
sub cist_statistiku
{
    my $soubor = $_[0];
    my $statref = $_[1];
    open(STAT, $soubor);
    print("�te se statistika $soubor [");
    my $oznameno = 0;
    my %cuzl;
    my $celkem = 0;
    while(<STAT>)
    {
	chomp;
	m/(.*)\t(\d+)/;
	my $k = $1;
	my $c = $2;
	my $hrana = $k;
	$statref->{$hrana} = $c;
	$celkem += $c;
	if($celkem>=$oznameno+10000)
	{
	    print(".");
	    $oznameno = $celkem;
	}
    }
    close(STAT);
    print("]\n");
    return $celkem;
}



#------------------------------------------------------------------------------
# Projde v�tu a ke ka�d�mu slovu zap�e informace, kter� m�me k dispozici
# ohledn� pravd�podobnosti jeho zav�en�.
#------------------------------------------------------------------------------
sub zpracovat_vetu
{
    my($i, $j, $k);
    if(!$vynechat_vetu)
    {
        $veta++;
        print STDERR (cas()." $soubor Zpracov�v� se v�ta $veta\n");
	$dbglog = $veta<=50;
	# Proj�t v�tu a naj�t potenci�ln� koordina�n� spojky.
	for($i = 1; $i<=$#slova; $i++)
	{
	    # Zjistit, kolikr�t jsme toto slovo vid�li p�i tr�ninku.
	    $uduss[$i] += ud("USS $slova[$i]");
	    # Zjistit, kolikr�t z toho bylo koordina�n� spojkou.
	    $udkjj[$i] += ud("KJJ $slova[$i]");
	}
	# Proj�t v�tu.
	for($i = 1; $i<=$#slova; $i++)
	{
	    for($j = 1; $j<=$#slova; $j++)
	    {
		# Nezji��ovat pravd�podobnost z�vislosti sama na sob�.
		if($i!=$j)
		{
		    my($s, $d) = zjistit_smer_a_delku($i, $j);
		    $udoss[$i][$j] += ud("OSS $slova[$i] $slova[$j] $s $d");
		    $udozz[$i][$j] += ud("OZZ $znacky[$i] $znacky[$j] $s $d");
		}
		# Pravd�podobnost z�vislosti je zji�t�na. Zjistit je�t�
		# pravd�podobnost koordinace. Pamatovat si pouze takov�
		# koordinace, ke kter�m aspo� s jistou pravd�podobnost�
		# najdeme koordina�n� spojku.
		my $kzz = ud("KZZ $znacky[$i] $znacky[$j]");
		for($k = $i+1; $k<$j; $k++)
		{
		    # Pokud slovo nezn�me jako koordina�n� spojku, pova�o-
		    # vat koordinaci p�es n�j za nemo�nou.
		    next unless $udkjj[$k];
		    # Ulo�it mo�nost koordinace.
		    $udkzz[$i][$j][$k] += $kzz;
		    $udkzz[$j][$i][$k] += $kzz;
		}
	    }
	}
    }
    # Vypsat v�tu v�etn� zji�t�n�ch mo�nost� do souboru ANALYZA.
    print $ANALYZA ("<s id=\"$veta\">\n");
    for($i = 1; $i<=$#slova; $i++)
    {
	# Vypsat informace, kter� zn�me ze vstupu, s v�jimkou na�ich vlastn�ch
	# syntaktick�ch informac� - ty te� m�me upraven�.
	my $csts = $csts[$i];
	$csts =~ s/<ud .*?>//g;
	print $ANALYZA ($csts);
	# P�ipsat statistiky ud�lost�, kter� se t�kaj� konkr�tn� tohoto slova.
	for($j = 0; $j<=$#udoss; $j++)
	{
	    if($udoss[$j][$i])
	    {
		print $ANALYZA ("<ud type=oss link=\"$j\" ".
				"w=\"$udoss[$j][$i]\" ".
				"tgtf=\"$slova[$j]\">");
	    }
	}
	for($j = 0; $j<=$#udozz; $j++)
	{
	    if($udozz[$j][$i])
	    {
		print $ANALYZA ("<ud type=ozz link=\"$j\" ".
				"w=\"$udozz[$j][$i]\" ".
				"tgtf=\"$slova[$j]\">");
	    }
	}
	for($j = 0; $j<=$#udkzz; $j++)
	{
	    for($k = 0; $k<=$#{$udkzz[$j]}; $k++)
	    {
		if($udkzz[$i][$j][$k])
		{
		    print $ANALYZA ("<ud type=kzz link=\"$k\" link2=\"$j\" ".
				    "w=\"$udkzz[$i][$j][$k]\" ".
				    "tgtf=\"$slova[$j]\">");
		}
	    }
	}
	if($uduss[$i])
	{
	    print $ANALYZA ("<ud type=uss w=\"$uduss[$i]\">");
	}
	if($udkjj[$i])
	{
	    print $ANALYZA ("<ud type=kjj w=\"$udkjj[$i]\">");
	}
	print $ANALYZA ("\n");
    }
    # Vymazat prom�nn�, aby bylo mo�n� ��st dal�� v�tu.
    vymazat_vetu();
}



#------------------------------------------------------------------------------
# Zjist� povolen� zav�en� uzlu v�etn� koordinac�.
#------------------------------------------------------------------------------
sub zjistit_moznosti_zaveseni
{
    my $z = $_[0];
    my $povol_z = $povol;
    # Odstranit ze seznamu povolen�ch z�vislost� ty, kter� zav�uj� jin� uzel.
    $povol_z =~ s/\d+-(?!$z,)\d+,//g;
    # P�epsat seznam z�vislost� na seznam ��d�c�ch uzl�.
    $povol_z =~ s/-$z,/,/g;
    my @r = split(/,/, $povol_z);
    # Vy�adit z�vislosti, kter� jsou na �ern� listin�.
    for(my $i = 0; $i<=$#r; $i++)
    {
	if(je_zakazana($r[$i], $z))
	{
	    splice(@r, $i, 1);
	    $i--;
	}
    }
    # Uspo��dat konkuren�n� z�vislosti podle vzd�lenosti ��d�c�ho uzlu od
    # z�visl�ho. Pokud se analyz�tor rozhodne skon�it u prvn�ho konkurenta,
    # kter� p�ed�� p�vodn�ho kandid�ta, bude zaji�t�no, �e dostane nejkrat��
    # takov� zav�en�.
    $povol_z = join(",", sort{abs($a-$z)<=>abs($b-$z);}(split(/,/, $povol_z)))
	.",";
    # Zapamatovat si po�et opravdov�ch z�vislost�, aby je volaj�c� mohl odli�it
    # od koordinac�.
    my $n_zavislosti = $#r+1;
    # Proj�t ��d�c� uzly a p�idat potenci�ln� koordinace.
    my @spojky;
    my($i, $j);
    for($i = 0; $i<$n_zavislosti; $i++)
    {
	# ��d�c� uzel mus� b�t zn�m jako potenci�ln� koordina�n� spojka.
	my $n_jako_koord = ud("KJJ $slova[$r[$i]]");
	my $n_jako_cokoli = ud("USS $slova[$r[$i]]");
	if($n_jako_koord>0 &&
	# Koordina�n� spojka nesm� ��dit n�kolik r�zn�ch koordinac� najednou.
	   !$coord[$r[$i]])
	{
	    # Naj�t potenci�ln�ho sourozence v koordinaci.
	    if($z<$r[$i])
	    {
		# Pokud u� spojka m� rodi�e, a to na t� stran�, na kter�
		# hled�me sourozence, spojen� se sourozencem nen� povoleno.
		if($rodic[$r[$i]]!=-1 && $rodic[$r[$i]]>$r[$i])
		{
		    next;
		}
		for($j = $rspan[$r[$i]]+1; $j<=$#slova; $j++)
		{
		    if($rodic[$j]==-1)
		    {
			# Nalezen potenci�ln� sourozenec. P�idat ho do pole.
			$spojky[++$#spojky] = $r[$i];
			$r[++$#r] = $j;
			last;
		    }
		}
	    }
	    else
	    {
		# Pokud u� spojka m� rodi�e, a to na t� stran�, na kter�
		# hled�me sourozence, spojen� se sourozencem nen� povoleno.
		if($rodic[$r[$i]]!=-1 && $rodic[$r[$i]]<$r[$i])
		{
		    next;
		}
		for($j = $lspan[$r[$i]]-1; $j>=0; $j--)
		{
		    if($rodic[$j]==-1)
		    {
			# Nalezen potenci�ln� sourozenec. P�idat ho do pole.
			$spojky[++$#spojky] = $r[$i];
			$r[++$#r] = $j;
			last;
		    }
		}
	    }
	}
    }
    # Vr�tit po�et z�vislost� a po�et koordinac�, n�sledovan� polem z�vislost�,
    # polem koordinac� a polem spojek.
    return($n_zavislosti, $#r-$n_zavislosti+1, @r, @spojky);
}



#------------------------------------------------------------------------------
# Zjist� pravd�podobnost hrany jako sou��sti koordinace.
#------------------------------------------------------------------------------
sub zjistit_pravdepodobnost_koordinace
{
    my $r = $_[0];
    my $z = $_[1];
    my $i;
    # Zjistit, zda ��d�c� �len m��e b�t koordina�n� spojkou.
    my $c = ud("KJJ $slova[$r]");
    if($c==0)
    {
	return(0, 0, "");
    }
    # Zjistit, v jak�m procentu pr�v� toto heslo ��d� koordinaci.
    my $prk = $c/ud("USS $slova[$r]");
    # Zna�ka prvn�ho �lena koordinace. Pokud vytv���m novou koordinaci, je to
    # zna�ka uzlu $z, pokud roz�i�uju existuj�c� koordinaci, mus�m ji p�e��st
    # v uzlu t�to koordinace.
    my $ja;
    # Pokud tato spojka u� byla pou�ita v n�jak� koordinaci, nen� mo�n� na ni
    # pov�sit novou koordinaci, ale je mo�n� st�vaj�c� koordinaci roz���it.
    if($coord[$r])
    {
	$ja = $znacky[$r];
	# Roz���en� existuj�c� koordinace. Z�visl� mus� b�t ��rka a mus� viset
	# nalevo od spojky.
	if($slova[$z] eq "," && $z<$r)
	{
	    # Zjistit, kdo by pak byl dal��m �lenem koordinace.
	    for($i = $z-1; $i>=0; $i--)
	    {
		if($rodic[$i]==-1)
		{
		    goto nalezeno;
		}
	    }
	    # Nebyl-li nalezen potenci�ln� sourozenec, nelze koordinaci
	    # roz���it a ��rka m� jinou funkci.
	    return(0, 0, "");
	  nalezeno1:
	    
	}
	else
	{
	    return(0, 0, "");
	}
    }
    else
    {
	$ja = $znacky[$z];
	# Zjistit m�ru koordina�n� ekvivalence mezi z�visl�m �lenem a
	# nejbli���m voln�m uzlem na druh� stran� od spojky.
	# Naj�t voln� uzel na druh� stran� od spojky.
	if($z<$r)
	{
	    for($i = $r+1; $i<=$#slova; $i++)
	    {
		if($rodic[$i]==-1)
		{
		    goto nalezeno;
		}
	    }
	}
	else
	{
	    for($i = $r-1; $i>=0; $i--)
	    {
		if($rodic[$i]==-1)
		{
		    goto nalezeno;
		}
	    }
	}
	# Na druh� stran� od spojky nen� ��dn� voln� uzel.
	return(0, 0, "");
    }
  nalezeno:
    my $sourozenec = $i;
    # Zjistit, zda potenci�ln� sourozenec nen� ve skute�nosti nad��zen� spojky.
    for($i = $rodic[$r]; $i!=-1; $i = $rodic[$i])
    {
	if($i==$sourozenec)
	{
	    return(0, 0, "");
	}
    }
    # Zjistit m�ru ekvivalence potenci�ln�ch sourozenc�.
    my $hrana = "KZZ $ja $znacky[$sourozenec]";
    $c = $ja eq $znacky[$sourozenec] ? $scelkem : ud($hrana);
    if($konfig{pabs})
    {
	$p = $prk*(1-$ls)*$c/$scelkem;
    }
    else
    {
	my $j = ud("UZZ $ja");
	$p = $j!=0 ? $prk*(1-$ls)*$c/$j : 0;
    }
    if($p>0 && $prk>0.5 && $ja eq $znacky[$sourozenec] && $ja=~m/^A/)
    {
	$p += 1;
    }
    # Nevypisovat lad�c� v�pisy o nezn�m�ch z�vislostech a neopakovat je na
    # konci, kdy� se pt�me na pravd�podobnost b�hem vypisov�n� stromu.
    if($p>0 && $povol ne "")
    {
	dbglog(sprintf("p($hrana)=%e\n", $p));
    }
    # Vr�tit nejen pravd�podobnost a �etnost, ale i hranu, kter� mus� zv�t�zit
    # v p��t�m kole, pokud nyn� zv�t�z� tato.
    return($p, $c, "$r-$sourozenec");
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

    ($smer, $delka) = zjistit_smer_a_delku($r, $z);
    my $prm = "$smer $delka";

    die("Model \"$konfig{model}\" ji� nen� podporov�n.\n")
	unless($konfig{model} eq "ls*slova+lz*znacky");
    $hrana = "OSS $slova[$r] $slova[$z] $prm";
    my $cs = ud($hrana);
    $hrana = "OZZ $znacky[$r] $znacky[$z] $prm";
    my $cz = ud($hrana);
    if($konfig{"pseudoval"})
    {
	if($znacky[$r]=~m/^V/)
	{
	    my $rrr = $znacky[$r].$hesla[$r];
	    $rrr =~ s/_.*//;
	    $cz += ud("ZPV $rrr $znacky[$z] $prm");
	}
    }
    my $ps;
    my $pz;
    if($konfig{pabs})
    {
	$ps = $cs/$scelkem;
	$pz = ($cz+1)/($scelkem+1);
    }
    else
    {
	my $j = ud("USS $slova[$z]");
	$ps = $j!=0 ? $cs/ud("USS $slova[$z]") : 0;
	$pz = ($cz+1)/(ud("UZZ $znacky[$z]")+1);
    }
    $c = $ls*$cs+$lz*$cz;
    $p = $ls*$ps+$lz*$pz;
    # Pro ��ely lad�c�ho v�pisu upravit popis hrany.
    $hrana = "$slova[$r]/$znacky[$r] $slova[$z]/$znacky[$z] $smer $delka";
    # Zvl�tn� zach�zen� se vzta�n�mi vedlej��mi v�tami.
    if($konfig{"vztaz"})
    {
	if(jde_o_vztaznou_vetu($r, $z))
	{
	    $p = 1;
	}
    }
    if($konfig{nekoord})
    {
	# Zjistit, zda ��d�c� �len m��e b�t koordina�n� spojkou.
	my $ckoord = ud("KJJ $slova[$r]");
	my $prk;
	# Zjistit, v jak�m procentu pr�v� toto heslo ��d� koordinaci.
	$prk = 0;
	my $cuss = ud("USS $slova[$r]");
	$prk = $ckoord/$cuss unless($cuss==0);
	# Pravd�podobnost z�vislosti pak bude vyn�sobena (1-$prk), aby byla
	# srovnateln� s pravd�podobnostmi koordinac�.
	$p *= 1-$prk;
    }
    return($p, $c);
}



#------------------------------------------------------------------------------
# Vr�t� po�et v�skyt� ud�losti.
#------------------------------------------------------------------------------
sub ud
{
    my @alt; # seznam alternativn�ch ud�lost�
    $alt[0] = $_[0];
    my $i;
    if($konfig{$mzdroj0} eq "MM")
    {
	# Rozd�lit alternativy do samostatn�ch ud�lost�.
	for($i = 0; $i<=$#alt; $i++)
	{
	    while($alt[$i] =~ m/([\S^\|]+)\|(\S+)/)
	    {
		my $alt0 = $1;
		my $zbytek = $2;
		$alt[++$#alt] = $alt[$i];
		$alt[$i] =~ s/$alt0\|$zbytek/$alt0/;
		$alt[$#alt] =~ s/$alt0\|$zbytek/$zbytek/;
	    }
	}
    }
    # Se��st v�skyty jednotliv�ch d�l��ch ud�lost�.
    my $n;
    for($i = 0; $i<=$#alt; $i++)
    {
	$n += $stat{$alt[$i]};
    }
    return $n;
}



#------------------------------------------------------------------------------
# Zjist�, zda dan� z�vislost je v dan� v�t� z�vislost� ko�enov�ho slovesa
# vzta�n� vedlej�� v�ty na nejbli��� jmenn� fr�zi vlevo. Vzta�n� z�jmeno u�
# mus� v tuto chv�li viset na slovesu.
#------------------------------------------------------------------------------
sub jde_o_vztaznou_vetu
{
    my $r = $_[0];
    my $z = $_[1];
    my $zajmeno;
    if($r<$z && $znacky[$z]=~m/^V/ && $znacky[$r]=~m/^[NP]/)
    {
	my $stav = 0;
	for($i = $z-1; $i>=0; $i--)
	{
	    if($stav==0 && $hesla[$i] eq "kter�" && ($rodic[$i]==$z || $rodic[$rodic[$i]]==$z && $znacky[$rodic[$i]]=~m/^R/))
	    {
		# Test shody.
		if(shoda_jmeno_vztazne_zajmeno($mznacky[$r], $slova[$i]))
		{
		    $zajmeno = $slova[$i];
		    $stav++;
		}
		else
		{
		    return 0;
		}
	    }
	    elsif($stav==1 && $slova[$i] eq "," && $rodic[$i]==$z)
	    {
		$stav++;
	    }
	    elsif($stav==2 && $znacky[$i]=~m/^[NP]/ &&
		  shoda_jmeno_vztazne_zajmeno($mznacky[$i], $zajmeno))
	    {
		if($i==$r)
		{
		    # Je�t� zkontrolovat, �e toto zav�en� je spr�vn�.
		    if($struktura[$z]==$r)
		    {
			$spravne_vztaz++;
			$chyba_vztaz = 0;
		    }
		    else
		    {
			$chyba_vztaz = 1;
		    }
		    $celkem_vztaz++;
		    return 1;
		}
		last;
	    }
	    elsif($i==$r && $stav!=2)
	    {
		last;
	    }
	}
    }
    return 0;
}



#------------------------------------------------------------------------------
# Zjist�, zda je shoda v rod� a ��sle (ne v p�d�) mezi jm�nem, jeho� morfolo-
# gickou zna�ku p�in�� prvn� parametr, a vzta�n�m z�jmenem, jeho� tvar p�in��
# druh� parametr.
#------------------------------------------------------------------------------
sub shoda_jmeno_vztazne_zajmeno
{
    my $znr = $_[0];
    my $slz = $_[1];
    my $vysledek =
	$slz=~m/(�|�ho|�mu|�m|�m)$/ && $znr=~m/^..[MI]S/ ||
	$slz=~m/(�|�ch|�m|�|�mi)$/ && $znr=~m/^..MP/ ||
	$slz=~m/(�|�ch|�m|�mi)$/ && $znr=~m/^..[IF]P/ ||
	$slz=~m/(�|�|ou)$/ && $znr=~m/^..FS/ ||
	$slz=~m/(�|�ho|�mu|�m|�m)$/ && $znr=~m/^..NS/ ||
	$slz=~m/(�|�ch|�m|�mi)$/ && $znr=~m/^..NP/;
    return $vysledek;
}



#------------------------------------------------------------------------------
# Otev�e soubor dan�ho jm�na, zap�e z�hlav� a vr�t� file handle.
#------------------------------------------------------------------------------
sub otevrit_csts_pro_zapis
{
    my $jmeno = $_[0];
    my $cislo = $_[1];
    my $soubor;
    open($soubor, ">".$jmeno);
    print $soubor <<EOF
<csts lang=cs>
<h>
<source>PDT</source>
</h>
<doc file=\"$jmeno\" id=\"$cislo\">
<a>
<mod>s
<txtype>pub
<genre>mix
<med>nws
<temp>1994
<authname>unknown
<opus>unknown
<id>0
</a>
<c>
<p n=\"1\">
EOF
    ;
    return $soubor;
}



#------------------------------------------------------------------------------
# Zap�e do souboru z�pat� a zav�e ho.
#------------------------------------------------------------------------------
sub zavrit_csts_pro_zapis
{
    my $soubor = $_[0];
    print $soubor <<EOF
</c>
</doc>
</csts>
EOF
    ;
    close($soubor);
}
