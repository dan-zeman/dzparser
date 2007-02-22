#!/usr/bin/perl

# Postupnì naète jednotlivé díly natrénovaného statistického modelu a oznaèí
# slova vstupních dat statistikami umo¾òujícími rozhodovat o jejich zavì¹ení
# v syntaktické struktuøe vìty. Vlastní syntaktickou analýzu zatím neprovádí.
# Rozdìlení statistiky do dílù sni¾uje pamì»ovou nároènost, ale zvy¹uje nároky
# na èas.



$starttime = time();



# Naèíst konfiguraci a knihovní funkce.
do "parslib.pl";



# Zaøídit autoflush na standardním výstupu, kam se prùbì¾nì hlásí stav.
my $old_fh = select(STDOUT);
$| = 1;
select($old_fh);



# Pøeèíst z konfigurace váhy slovního a znaèkového modelu (vlastnì si zde
# zøizujeme zkratky, abychom my ani Perl nemuseli pozdìji pou¾ívat dlouhou
# notaci $konfig{ls}.
$ls = $konfig{ls};
$lz = 1-$ls;



# Postupnì èíst natrénované èásti statistického modelu a pro ka¾dou z nich
# projít analyzovaný vstup a ulo¾it do nìj k nìmu se vá¾ící statistiky.

$maska = $konfig{prac}."/".$konfig{stat}."*";
$maska_perl = $konfig{prac}."/".$konfig{stat}."\\d+";
print("Maska pro soubory se statistikou je $maska.\n");
@statistiky = glob($maska);
print("Nalezeno ".($#statistiky+1)." souborù odpovídajících masce.\n");
for($istat = 0; $istat<=$#statistiky; $istat++)
{
    # Pozor, nìkteré soubory nemusejí pocházet od dìleného tréninku!
    # Nemù¾eme jednodu¹e skoèit na dal¹í prùchod cyklem, proto¾e první skuteèný
    # prùchod se chová trochu jinak ne¾ ostatní, a pozná se podle $istat==0.
    while($statistiky[$istat] !~ m/^$maska_perl$/ && $#statistiky>=0)
    {
	shift(@statistiky);
    }
    $scelkem = cist_statistiku($statistiky[$istat], \%stat);
    # Je-li statistika prázdná, zkusit rovnou dal¹í.
    next if($scelkem==0);
    # Èíst testovací vìty a analyzovat je.
    @soubory = glob($konfig{test});
    $maxc_spatne = 0;
    # Nachystat koøen stromu, pro v¹echny vìty stejný.
    $slova[0] = "#";
    $hesla[0] = "#";
    $znacky[0] = "#";
    # Globální promìnná se jménem aktuálního souboru se pou¾ívá pøi vypisování
    # diagnostických informací o právì zpracovávaném vstupu.
    $soubor = $soubory[0];
    # Projít vstupní soubory, pøeèíst je a zpracovat je.
    for($isoubor = 0; $isoubor<=$#soubory; $isoubor++)
    {
	# Poprvé èíst soubor z místa urèeného konfigurací.
	# Pro druhou a dal¹í statistiku èíst u¾ ulo¾ené výsledky pøedcházející
	# statistiky. Výsledky se ukládají do souborù stejného jména, ale
	# v pracovní slo¾ce.
	my $vystup = $soubory[$isoubor];
	$vystup =~ s/^.*[\/\\]//;
	$vystup = $konfig{prac}."/".$vystup;
	if($istat==0)
	{
	    open(SOUBOR, $soubory[$isoubor]);
	    # Zkontrolovat, ¾e nehrozí, ¾e výstupem pøepí¹eme vstup.
	    if($vystup eq $soubory[$isoubor])
	    {
		die("Nelze pokraèovat, proto¾e výstupem by se pøepsal ".
		    "vstup.\n");
	    }
	    $ANALYZA = otevrit_csts_pro_zapis($vystup, $isoubor);
	}
	else
	{
	    # Zkopírovat výstup pøedcházející statistiky, aby se kopie dala
	    # pou¾ít jako nový vstup, zatímco výstup by se u¾ pøepisoval.
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
	# Zpracovat øádky aktuálního vstupního souboru.
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
	# Po pøeètení souboru zpracovat poslední vìtu (po ní nenásleduje ¾ádné
	# dal¹í <s>, které normálnì zpracování vìty spou¹tí).
	if($ord>0)
	{
	    zpracovat_vetu();
	}
	zavrit_csts_pro_zapis($ANALYZA);
	close(SOUBOR);
    }
    # Pøed pøechodem k dal¹í statistice vymazat tu souèasnou.
    undef(%stat);
    undef($veta);
}



# Vypsat údaje o dobì trvání programu.
$stoptime = time();
$cas = $stoptime-$starttime;
$hod = int($cas/3600);
$min = int(($cas%3600)/60);
$sek = $cas%60;
printf("Program bì¾el %02d:%02d:%02d hodin.\n", $hod, $min, $sek);



###############################################################################
# Podprogramy
###############################################################################



#------------------------------------------------------------------------------
# Naète statistický model závislostí na urèitých datech (napø. na znaèkách).
#------------------------------------------------------------------------------
sub cist_statistiku
{
    my $soubor = $_[0];
    my $statref = $_[1];
    open(STAT, $soubor);
    print("Ète se statistika $soubor [");
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
# Projde vìtu a ke ka¾dému slovu zapí¹e informace, které máme k dispozici
# ohlednì pravdìpodobnosti jeho zavì¹ení.
#------------------------------------------------------------------------------
sub zpracovat_vetu
{
    my($i, $j, $k);
    if(!$vynechat_vetu)
    {
        $veta++;
        print STDERR (cas()." $soubor Zpracovává se vìta $veta\n");
	$dbglog = $veta<=50;
	# Projít vìtu a najít potenciální koordinaèní spojky.
	for($i = 1; $i<=$#slova; $i++)
	{
	    # Zjistit, kolikrát jsme toto slovo vidìli pøi tréninku.
	    $uduss[$i] += ud("USS $slova[$i]");
	    # Zjistit, kolikrát z toho bylo koordinaèní spojkou.
	    $udkjj[$i] += ud("KJJ $slova[$i]");
	}
	# Projít vìtu.
	for($i = 1; $i<=$#slova; $i++)
	{
	    for($j = 1; $j<=$#slova; $j++)
	    {
		# Nezji¹»ovat pravdìpodobnost závislosti sama na sobì.
		if($i!=$j)
		{
		    my($s, $d) = zjistit_smer_a_delku($i, $j);
		    $udoss[$i][$j] += ud("OSS $slova[$i] $slova[$j] $s $d");
		    $udozz[$i][$j] += ud("OZZ $znacky[$i] $znacky[$j] $s $d");
		}
		# Pravdìpodobnost závislosti je zji¹tìna. Zjistit je¹tì
		# pravdìpodobnost koordinace. Pamatovat si pouze takové
		# koordinace, ke kterým aspoò s jistou pravdìpodobností
		# najdeme koordinaèní spojku.
		my $kzz = ud("KZZ $znacky[$i] $znacky[$j]");
		for($k = $i+1; $k<$j; $k++)
		{
		    # Pokud slovo neznáme jako koordinaèní spojku, pova¾o-
		    # vat koordinaci pøes nìj za nemo¾nou.
		    next unless $udkjj[$k];
		    # Ulo¾it mo¾nost koordinace.
		    $udkzz[$i][$j][$k] += $kzz;
		    $udkzz[$j][$i][$k] += $kzz;
		}
	    }
	}
    }
    # Vypsat vìtu vèetnì zji¹tìných mo¾ností do souboru ANALYZA.
    print $ANALYZA ("<s id=\"$veta\">\n");
    for($i = 1; $i<=$#slova; $i++)
    {
	# Vypsat informace, které známe ze vstupu, s výjimkou na¹ich vlastních
	# syntaktických informací - ty teï máme upravené.
	my $csts = $csts[$i];
	$csts =~ s/<ud .*?>//g;
	print $ANALYZA ($csts);
	# Pøipsat statistiky událostí, které se týkají konkrétnì tohoto slova.
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
    # Vymazat promìnné, aby bylo mo¾né èíst dal¹í vìtu.
    vymazat_vetu();
}



#------------------------------------------------------------------------------
# Zjistí povolená zavì¹ení uzlu vèetnì koordinací.
#------------------------------------------------------------------------------
sub zjistit_moznosti_zaveseni
{
    my $z = $_[0];
    my $povol_z = $povol;
    # Odstranit ze seznamu povolených závislostí ty, které zavì¹ují jiný uzel.
    $povol_z =~ s/\d+-(?!$z,)\d+,//g;
    # Pøepsat seznam závislostí na seznam øídících uzlù.
    $povol_z =~ s/-$z,/,/g;
    my @r = split(/,/, $povol_z);
    # Vyøadit závislosti, které jsou na èerné listinì.
    for(my $i = 0; $i<=$#r; $i++)
    {
	if(je_zakazana($r[$i], $z))
	{
	    splice(@r, $i, 1);
	    $i--;
	}
    }
    # Uspoøádat konkurenèní závislosti podle vzdálenosti øídícího uzlu od
    # závislého. Pokud se analyzátor rozhodne skonèit u prvního konkurenta,
    # který pøedèí pùvodního kandidáta, bude zaji¹tìno, ¾e dostane nejkrat¹í
    # takové zavì¹ení.
    $povol_z = join(",", sort{abs($a-$z)<=>abs($b-$z);}(split(/,/, $povol_z)))
	.",";
    # Zapamatovat si poèet opravdových závislostí, aby je volající mohl odli¹it
    # od koordinací.
    my $n_zavislosti = $#r+1;
    # Projít øídící uzly a pøidat potenciální koordinace.
    my @spojky;
    my($i, $j);
    for($i = 0; $i<$n_zavislosti; $i++)
    {
	# Øídící uzel musí být znám jako potenciální koordinaèní spojka.
	my $n_jako_koord = ud("KJJ $slova[$r[$i]]");
	my $n_jako_cokoli = ud("USS $slova[$r[$i]]");
	if($n_jako_koord>0 &&
	# Koordinaèní spojka nesmí øídit nìkolik rùzných koordinací najednou.
	   !$coord[$r[$i]])
	{
	    # Najít potenciálního sourozence v koordinaci.
	    if($z<$r[$i])
	    {
		# Pokud u¾ spojka má rodièe, a to na té stranì, na které
		# hledáme sourozence, spojení se sourozencem není povoleno.
		if($rodic[$r[$i]]!=-1 && $rodic[$r[$i]]>$r[$i])
		{
		    next;
		}
		for($j = $rspan[$r[$i]]+1; $j<=$#slova; $j++)
		{
		    if($rodic[$j]==-1)
		    {
			# Nalezen potenciální sourozenec. Pøidat ho do pole.
			$spojky[++$#spojky] = $r[$i];
			$r[++$#r] = $j;
			last;
		    }
		}
	    }
	    else
	    {
		# Pokud u¾ spojka má rodièe, a to na té stranì, na které
		# hledáme sourozence, spojení se sourozencem není povoleno.
		if($rodic[$r[$i]]!=-1 && $rodic[$r[$i]]<$r[$i])
		{
		    next;
		}
		for($j = $lspan[$r[$i]]-1; $j>=0; $j--)
		{
		    if($rodic[$j]==-1)
		    {
			# Nalezen potenciální sourozenec. Pøidat ho do pole.
			$spojky[++$#spojky] = $r[$i];
			$r[++$#r] = $j;
			last;
		    }
		}
	    }
	}
    }
    # Vrátit poèet závislostí a poèet koordinací, následovaný polem závislostí,
    # polem koordinací a polem spojek.
    return($n_zavislosti, $#r-$n_zavislosti+1, @r, @spojky);
}



#------------------------------------------------------------------------------
# Zjistí pravdìpodobnost hrany jako souèásti koordinace.
#------------------------------------------------------------------------------
sub zjistit_pravdepodobnost_koordinace
{
    my $r = $_[0];
    my $z = $_[1];
    my $i;
    # Zjistit, zda øídící èlen mù¾e být koordinaèní spojkou.
    my $c = ud("KJJ $slova[$r]");
    if($c==0)
    {
	return(0, 0, "");
    }
    # Zjistit, v jakém procentu právì toto heslo øídí koordinaci.
    my $prk = $c/ud("USS $slova[$r]");
    # Znaèka prvního èlena koordinace. Pokud vytváøím novou koordinaci, je to
    # znaèka uzlu $z, pokud roz¹iøuju existující koordinaci, musím ji pøeèíst
    # v uzlu této koordinace.
    my $ja;
    # Pokud tato spojka u¾ byla pou¾ita v nìjaké koordinaci, není mo¾né na ni
    # povìsit novou koordinaci, ale je mo¾né stávající koordinaci roz¹íøit.
    if($coord[$r])
    {
	$ja = $znacky[$r];
	# Roz¹íøení existující koordinace. Závislá musí být èárka a musí viset
	# nalevo od spojky.
	if($slova[$z] eq "," && $z<$r)
	{
	    # Zjistit, kdo by pak byl dal¹ím èlenem koordinace.
	    for($i = $z-1; $i>=0; $i--)
	    {
		if($rodic[$i]==-1)
		{
		    goto nalezeno;
		}
	    }
	    # Nebyl-li nalezen potenciální sourozenec, nelze koordinaci
	    # roz¹íøit a èárka má jinou funkci.
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
	# Zjistit míru koordinaèní ekvivalence mezi závislým èlenem a
	# nejbli¾¹ím volným uzlem na druhé stranì od spojky.
	# Najít volný uzel na druhé stranì od spojky.
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
	# Na druhé stranì od spojky není ¾ádný volný uzel.
	return(0, 0, "");
    }
  nalezeno:
    my $sourozenec = $i;
    # Zjistit, zda potenciální sourozenec není ve skuteènosti nadøízený spojky.
    for($i = $rodic[$r]; $i!=-1; $i = $rodic[$i])
    {
	if($i==$sourozenec)
	{
	    return(0, 0, "");
	}
    }
    # Zjistit míru ekvivalence potenciálních sourozencù.
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
    # Nevypisovat ladící výpisy o neznámých závislostech a neopakovat je na
    # konci, kdy¾ se ptáme na pravdìpodobnost bìhem vypisování stromu.
    if($p>0 && $povol ne "")
    {
	dbglog(sprintf("p($hrana)=%e\n", $p));
    }
    # Vrátit nejen pravdìpodobnost a èetnost, ale i hranu, která musí zvítìzit
    # v pøí¹tím kole, pokud nyní zvítìzí tato.
    return($p, $c, "$r-$sourozenec");
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

    ($smer, $delka) = zjistit_smer_a_delku($r, $z);
    my $prm = "$smer $delka";

    die("Model \"$konfig{model}\" ji¾ není podporován.\n")
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
    # Pro úèely ladícího výpisu upravit popis hrany.
    $hrana = "$slova[$r]/$znacky[$r] $slova[$z]/$znacky[$z] $smer $delka";
    # Zvlá¹tní zacházení se vzta¾nými vedlej¹ími vìtami.
    if($konfig{"vztaz"})
    {
	if(jde_o_vztaznou_vetu($r, $z))
	{
	    $p = 1;
	}
    }
    if($konfig{nekoord})
    {
	# Zjistit, zda øídící èlen mù¾e být koordinaèní spojkou.
	my $ckoord = ud("KJJ $slova[$r]");
	my $prk;
	# Zjistit, v jakém procentu právì toto heslo øídí koordinaci.
	$prk = 0;
	my $cuss = ud("USS $slova[$r]");
	$prk = $ckoord/$cuss unless($cuss==0);
	# Pravdìpodobnost závislosti pak bude vynásobena (1-$prk), aby byla
	# srovnatelná s pravdìpodobnostmi koordinací.
	$p *= 1-$prk;
    }
    return($p, $c);
}



#------------------------------------------------------------------------------
# Vrátí poèet výskytù události.
#------------------------------------------------------------------------------
sub ud
{
    my @alt; # seznam alternativních událostí
    $alt[0] = $_[0];
    my $i;
    if($konfig{$mzdroj0} eq "MM")
    {
	# Rozdìlit alternativy do samostatných událostí.
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
    # Seèíst výskyty jednotlivých dílèích událostí.
    my $n;
    for($i = 0; $i<=$#alt; $i++)
    {
	$n += $stat{$alt[$i]};
    }
    return $n;
}



#------------------------------------------------------------------------------
# Zjistí, zda daná závislost je v dané vìtì závislostí koøenového slovesa
# vzta¾né vedlej¹í vìty na nejbli¾¹í jmenné frázi vlevo. Vzta¾né zájmeno u¾
# musí v tuto chvíli viset na slovesu.
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
	    if($stav==0 && $hesla[$i] eq "který" && ($rodic[$i]==$z || $rodic[$rodic[$i]]==$z && $znacky[$rodic[$i]]=~m/^R/))
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
		    # Je¹tì zkontrolovat, ¾e toto zavì¹ení je správné.
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
# Zjistí, zda je shoda v rodì a èísle (ne v pádì) mezi jménem, jeho¾ morfolo-
# gickou znaèku pøiná¹í první parametr, a vzta¾ným zájmenem, jeho¾ tvar pøiná¹í
# druhý parametr.
#------------------------------------------------------------------------------
sub shoda_jmeno_vztazne_zajmeno
{
    my $znr = $_[0];
    my $slz = $_[1];
    my $vysledek =
	$slz=~m/(ý|ého|ému|ém|ým)$/ && $znr=~m/^..[MI]S/ ||
	$slz=~m/(í|ých|ým|é|ými)$/ && $znr=~m/^..MP/ ||
	$slz=~m/(é|ých|ým|ými)$/ && $znr=~m/^..[IF]P/ ||
	$slz=~m/(á|é|ou)$/ && $znr=~m/^..FS/ ||
	$slz=~m/(é|ého|ému|ém|ým)$/ && $znr=~m/^..NS/ ||
	$slz=~m/(á|ých|ým|ými)$/ && $znr=~m/^..NP/;
    return $vysledek;
}



#------------------------------------------------------------------------------
# Otevøe soubor daného jména, zapí¹e záhlaví a vrátí file handle.
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
# Zapí¹e do souboru zápatí a zavøe ho.
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
