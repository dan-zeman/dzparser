package genstav;
use povol;
use zakaz;
use model;
use lokon;
use stav;
use vystupy; # kv�li chybov�m a lad�c�m v�pis�m



#------------------------------------------------------------------------------
# Vezme aktu�ln� stav (les), projde z�vislosti, kter� je mo�n� p�idat, zjist�
# jejich pravd�podobnosti a nageneruje p��slu�n� pokra�ovac� stavy. Vrac� hash
# s prvky r (index ��d�c�ho), z (index z�visl�ho), c (�etnost) a p (pravd�po-
# dobnost).
#------------------------------------------------------------------------------
sub generovat_stavy
{
    my $stav = shift; # odkaz na hash s dosavadn�m stavem anal�zy
    my $generovat_vse = shift; # generovat v�echny pokra�ovac� stavy, nebo jen v�t�zn�?
    # Zat�m glob�ln� prom�nn�.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    # Zjistit seznam z�vislost�, jejich� p�id�n� do stromu je moment�ln� povolen�.
    my @povol = povol::zjistit_povol($stav->{rodic});
    # Ulo�it seznam povolen�ch hran do stavu anal�zy, jednak aby se o n�m dozv�d�ly volan� funkce
    # (t�eba p�i navrhov�n� koordinace je pot�eba v�d�t, zda je povolena i druh� hrana), jednak
    # kv�li lad�n�, aby bylo mo�n� zp�tn� zjistit, z jak�ch hran jsme vyb�rali.
    $stav->{povol} = \@povol;
    # Nejd��ve spojit ko�en s koncovou interpunkc�. Zde nepust�me statistiku v�bec ke slovu.
    my $nove_stavy;
    if($konfig->{koncint})
    {
        if($nove_stavy = generovat_pro_koncovou_interpunkci($stav, $anot, $generovat_vse))
        {
            return $nove_stavy;
        }
    }
    # Zjistit, zda jsme v minul�m kole nep�ipojovali prvn� ��st koordinace.
    # To bychom v tomto kole byli povinni p�ipojit zbytek.
    if($nove_stavy = generovat_pro_druhou_cast_koordinace($stav, $generovat_vse))
    {
        return $nove_stavy;
    }
    # Pokud je mezi povolen�mi z�vislostmi nejl�pe hodnocen� valen�n�
    # z�vislost, vybere se ona (i kdyby n�kter� nevalen�n� byly lep��).
    if($konfig->{valence})
    {
        if($nove_stavy = generovat_pro_valencni_zavislost($stav, $generovat_vse))
        {
            return $nove_stavy;
        }
    }
    # Proj�t povolen� a nezak�zan� z�vislosti, vygenerovat pro n� stavy a vr�tit jejich seznam.
    # Zat�m se pomoc� parametru %max z�sk�v� zvlṻ i popis v�t�zn�ho kandid�ta.
    # �asem to p�estane b�t pot�eba, proto�e prvn� stav v seznamu bude odpov�dat tomuto kandid�tovi.
    my %max;
    $nove_stavy = generovat_zaklad($stav, \%max, $generovat_vse);
    # Jestli�e m�me generovat i z�lo�n� stavy, zjistit k nim tak� v�hy, podle kter�ch
    # bude mo�n� mezi nimi vyb�rat.
    if($generovat_vse)
    {
        for(my $i = 0; $i<=$#{$nove_stavy}; $i++)
        {
            my $prst_moje = $nove_stavy->[$i]{maxp}[$nove_stavy->[$i]{poslz}];
            my $prst_viteze = $nove_stavy->[0]{maxp}[$nove_stavy->[0]{poslz}];
            if($prst_viteze!=0)
            {
                $nove_stavy->[$i]{vaha} = $prst_moje/$prst_viteze;
            }
            elsif($prst_moje>0)
            {
                $nove_stavy->[$i]{vaha} = 1;
            }
            else
            {
                $nove_stavy->[$i]{vaha} = 0;
            }
        }
        # Se�adit nov� stavy podle v�hy. D�l�me to je�t� p�ed �e�en�m lok�ln�ch konflikt�.
        # Pokud n�kdo vyhraje na z�klad� nich, bude vyta�en mimo po�ad�.
        @{$nove_stavy} = sort{$b->{vaha}<=>$a->{vaha}}(@{$nove_stavy});
    }
    if($konfig->{lokon})
    {
        # Je vybr�n v�t�zn� kandid�t na z�klad� sv� relativn� �etnosti bez
        # ohledu na kontext. Te� zohlednit kontext a pokusit se vy�e�it lok�ln�
        # konflikty.
        lokalni_konflikty($stav, $nove_stavy, $generovat_vse);
    }
    # Vr�tit cel� pole.
    return $nove_stavy;
}



#------------------------------------------------------------------------------
# Vezme aktu�ln� stav, zkontroluje, zda u� byla zav�ena koncov� interpunkce,
# a pokud ne, zav�s� ji a vr�t� odkaz na pole, jeho� jedin�m prvkem je v�sledn�
# stav.
#------------------------------------------------------------------------------
sub generovat_pro_koncovou_interpunkci
{
    my $stav = shift; # odkaz na hash
    my $anot = shift; # odkaz na pole hash�
    my $generovat_vse = shift; # generovat v�echny pokra�ovac� stavy, nebo jen v�t�zn�?
    if($stav->{rodic}[$#{$anot}]==-1 && $anot->[$#{$anot}]{uznacka}=~m/^Z/)
    {
        my $r = 0;
        my $z = $#{$anot};
        my $stav1 = $generovat_vse ? stav::zduplikovat($stav) : $stav;
        stav::pridat_zavislost($stav1, model::ohodnotit_hranu($r, $z, $stav1));
        my @vysledek;
        push(@vysledek, $stav1);
        return \@vysledek;
    }
    else
    {
        return "";
    }
}



#------------------------------------------------------------------------------
# Vezme aktu�ln� stav, zkontroluje, zda se m� tvo�it druh� ��st koordinace,
# a pokud ano, zav�s� ji a vr�t� odkaz na pole, jeho� jedin�m prvkem je
# v�sledn� stav.
#------------------------------------------------------------------------------
sub generovat_pro_druhou_cast_koordinace
{
    my $stav = shift; # odkaz na hash
    my $generovat_vse = shift; # generovat v�echny pokra�ovac� stavy, nebo jen v�t�zn�?
    if($stav->{priste}=~m/^(\d+)-(\d+)$/)
    {
        my $r = $1;
        my $z = $2;
        # Pro v�echny p��pady ov��it, �e tato z�vislost je povolen�.
        if(!povol::je_povoleno($r, $z, $stav->{povol}))
        {
            vypsat("prubeh", "Po�adov�no povinn� p�id�n� z�vislosti $r-$z.\n");
            vypsat("prubeh", "Povoleny jsou z�vislosti ".join(",", @{$stav->{povol}})."\n");
            die("CHYBA! Druh� ��st koordinace p�estala b�t po p�id�n� prvn� ��sti povolena.\n");
        }
        my $stav1 = $generovat_vse ? stav::zduplikovat($stav) : $stav;
        $stav1->{priste} = "";
        stav::pridat_zavislost($stav1, {"r" => $r, "z" => $z, "c" => 0, "p" => "1"});
        my @vysledek;
        push(@vysledek, $stav1);
        return \@vysledek;
    }
    else
    {
        return "";
    }
}



#------------------------------------------------------------------------------
# Vezme aktu�ln� stav, zkontroluje, zda lze p�idat valen�n� z�vislost, a pokud
# ano, zav�s� ji a vr�t� odkaz na pole, jeho� jedin�m prvkem je v�sledn� stav.
#------------------------------------------------------------------------------
sub generovat_pro_valencni_zavislost
{
    my $generovat_vse = shift; # generovat v�echny pokra�ovac� stavy, nebo jen v�t�zn�?
    my $stav = shift; # odkaz na hash
    if($#{$stav->{valencni}}>=0)
    {
        $stav->{valencni}[0] =~ m/^(\d+)-(\d+)/;
        my %max;
        $max{r} = $1;
        $max{z} = $2;
        # Zjistit, zda je nejlep�� valen�n� z�vislost mezi povolen�mi.
        for(my $i = 0; $i<=$#{$stav->{povol}}; $i++)
        {
            if($stav->{povol}[$i] eq "$max{r}-$max{z}" && !zakaz::je_zakazana($stav->{zakaz}, $max{r}, $max{z}))
            {
                my $stav1 = $generovat_vse ? stav::zduplikovat($stav) : $stav;
                shift(@{$stav1->{valencni}});
                ($max{p}, $max{c}) = model::zjistit_pravdepodobnost($max{r}, $max{z}, $stav1);
                stav::pridat_zavislost($stav1, \%max);
                my @vysledek;
                push(@vysledek, $stav1);
                return \@vysledek;
            }
        }
    }
    return "";
}



#------------------------------------------------------------------------------
# Projde povolen� a nezak�zan� z�vislosti, pro ka�dou vygeneruje stav anal�zy,
# jako kdyby tato z�vislost byla p�id�na do stromu, a vybere nejlep�� z t�chto
# stav�. Pokud nejsou k dispozici povolen� a nezak�zan� hrany, zru�� v�echny
# z�kazy. Vr�t� seznam pokra�ovac�ch stav�, na prvn�m m�st� v�t�ze.
#------------------------------------------------------------------------------
sub generovat_zaklad
{
    my $stav = shift; # odkaz na hash
    my $max = shift; # odkaz, kam opsat v�t�zn�ho kandid�ta
    my $generovat_vse = shift; # generovat v�echny pokra�ovac� stavy, nebo jen v�t�zn�?
    my @nove_stavy;
    my $index_viteze;
    # Generov�n� p��padn� opakovat dvakr�t. Pokud se napoprv� nic nenajde, zru�it v�echny z�kazy a zkusit to znova.
    for(; $max->{p} eq "";)
    {
        die("CHYBA! Nen� povolena ani jedna z�vislost a hroz� nekone�n� smy�ka.\n") unless($#{$stav->{povol}}+1);
        for(my $i = 0; $i<=$#{$stav->{povol}}; $i++)
        {
            # P�e��st z�vislost - kandid�ta.
            $stav->{povol}[$i] =~ m/(\d+)-(\d+)/;
            my $r = $1;
            my $z = $2;
            # Pokud je z�vislost na �ern� listin�, vy�adit ji ze sout�e.
            # �ern� listina $zakaz m� vy��� prioritu ne� $povol.
            if(zakaz::je_zakazana($stav->{zakaz}, $r, $z))
            {
                next;
            }
            # P�idat do seznamu pokra�ovac� stav pro tuto z�vislost.
            my $kandidat = model::ohodnotit_hranu($r, $z, $stav);
            if($generovat_vse)
            {
                my $stav1 = stav::zduplikovat($stav);
                stav::pridat_zavislost($stav1, $kandidat);
                push(@nove_stavy, $stav1);
            }
            # Zjistit, zda je tato pravd�podobnost vy��� ne� pravd�podobnosti
            # z�vislost� testovan�ch v p�edchoz�ch pr�chodech.
            if($max->{p} eq "" || $kandidat->{p}>$max->{p}) # i==0 nefunguje, kvuli $zakaz
            {
                %{$max} = %{$kandidat};
                # U pole nov�ch stav� si zat�m pamatovat jen index nejlep��ho pokra�ovac�ho stavu.
                $index_viteze = $#nove_stavy;
            }
        }
        # Pokud se mezi povolen�mi nena�la jedin� nezak�zan� z�vislost, nouzov�
        # situace: zru�it v�echny z�kazy pro tuto v�tu.
        if($max->{p} eq "")
        {
            $stav->{zakaz} = "";
        }
    }
    # Pokud se nem�ly generovat v�echny pokra�ovac� stavy, je te� �as vygenerovat
    # ten jeden v�t�zn�.
    unless($generovat_vse)
    {
        my $stav1 = stav::zduplikovat($stav);
        stav::pridat_zavislost($stav1, $max);
        $nove_stavy[0] = $stav1;
    }
    else
    {
        # P�ed n�vratem za��dit, aby v�t�zn� kandid�t byl v seznamu nov�ch stav� na prvn�m m�st�.
        my $vitezny_stav = $nove_stavy[$index_viteze];
        splice(@nove_stavy, $index_viteze, 1);
        unshift(@nove_stavy, $vitezny_stav);
    }
    return \@nove_stavy;
}



#------------------------------------------------------------------------------
# P�ehodnot� n�zor na v�t�ze na z�klad� modelu lok�ln�ch konflikt�. Mno�inu
# nov�ch stav� nem�n�, m��e v�ak zm�nit po�ad� nov�ch stav�.
#------------------------------------------------------------------------------
sub lokalni_konflikty
{
    my $stav = shift; # odkaz na hash s dosavadn�m stavem (nov� kandid�t je�t� nebyl p�id�n)
    my $nove_stavy = shift; # odkaz na pole hash� s nov�mi stavy; prvn� z nich je v�t�z ze z�kladn�ho kola
    my $generovat_vse = shift; # generovat v�echny pokra�ovac� stavy, nebo jen v�t�zn�?
    my $poslz = $nove_stavy->[0]{poslz};
    my %max0 =
    (
        "r" => $nove_stavy->[0]{rodic}[$poslz],
        "z" => $poslz,
        "c" => $nove_stavy->[0]{maxc}[$poslz],
        "p" => $nove_stavy->[0]{maxp}[$poslz],
        "priste" => $nove_stavy->[0]{priste}
    );
    my %max1 = lokon::lokalni_konflikty(\%max0, $stav);
    # Vrstva kompatibility mezi starou implementac� lok�ln�ch konflikt� a novou
    # implementac� generov�n� stav�. Naj�t mezi nov�mi stavy ten, kter� reprezentuje
    # v�t�ze lok�ln�ch konflikt�. Lep�� by bylo, kdyby modul lokon pracoval
    # rovnou s polem nov�ch stav�.
    if($max1{r}!=$max0{r} || $max1{z}!=$max0{z})
    {
        # Pokud se nem�ly generovat v�echny pokra�ovac� stavy, nem�me nikde nachystan�
        # stav, ve kter�m m�sto z�kladn�ho v�t�ze vyhr�l v�t�z lok�ln�ho konfliktu,
        # a mus�me ho vygenerovat te�.
        unless($generovat_vse)
        {
            my $stav1 = stav::zduplikovat($stav);
            stav::pridat_zavislost($stav1, \%max1);
            $nove_stavy->[0] = $stav1;
        }
        # Jinak sta�� nov�ho v�t�ze mezi stavy naj�t a p�esunout na prvn� m�sto.
        else
        {
            my $index_viteze = 0;
            for(my $i = 1; $i<=$#{$nove_stavy}; $i++)
            {
                my $novez = $nove_stavy->[$i]{poslz};
                my $nover = $nove_stavy->[$i]{rodic}[$novez];
                if($nover==$max1{r} && $novez==$max1{z})
                {
                    $index_viteze = $i;
                    last;
                }
            }
            # P�ed n�vratem za��dit, aby v�t�zn� kandid�t byl v seznamu nov�ch stav� op�t na prvn�m m�st�.
            my $vitezny_stav = $nove_stavy->[$index_viteze];
            splice(@{$nove_stavy}, $index_viteze, 1);
            unshift(@{$nove_stavy}, $vitezny_stav);
        }
    }
}



1;
