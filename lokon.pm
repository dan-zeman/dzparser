package lokon;
use zakaz;
use model; # jen kv�li sub ud()



#------------------------------------------------------------------------------
# Pokus� se vy�e�it lok�ln� konflikty konkuren�n�ch zav�en� uzlu, a to na
# z�klad� kontextu. Pravd�podobnost ur�it�ho zav�en� uzlu m��e b�t jin�, pokud
# v�me, �e jeho konkurenc� bylo konkr�tn� jin� zav�en�.
#
# Vr�t� odkazy na konkurenta, kter� zv�t�zil (t�m m��e b�t i p�vodn� kandid�t).
#------------------------------------------------------------------------------
sub lokalni_konflikty
{
    my $navrh0 = shift; # odkaz na hash se zat�m nejlep�� hranou (r, z, c, p...)
    my $stav = shift; # odkaz na hash se stavem anal�zy
    my $r = $navrh0->{r}; # index ��d�c�ho uzlu hrany, kterou navrhl p�vodn� model
    my $z = $navrh0->{z}; # index z�visl�ho uzlu hrany, kterou navrhl p�vodn� model
    my $priste = $navrh0->{priste}; # u koordinac�: druh� polovina do p��t�ho kola
    my @povol = @{$stav->{povol}}; # seznam moment�ln� povolen�ch hran
    # Zat�m glob�ln� prom�nn�.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    my $rmax = $r;
    my $zmax = $z;
    my $pristemax = $priste;
    my $maxsila;
    # Zapsat informaci o kandid�tovi na ��d�c�ho zp�sobem slu�iteln�m se
    # statistikou o konfliktech.
    my $kandidat;
    if($priste eq "")
    {
        $kandidat = $stav->{uznck}[$r];
    }
    else
    {
        $priste =~ m/$r-(\d+)/;
        $kandidat = "C $stav->{uznck}[$1]";
    }
    # Zjistit konkurenty.
    my $nz; # kolik konkurent� jsou z�vislosti
    my $nk; # kolik konkurent� jsou koordinace (nejd��v sourozenci, pak spojky)
    my @konkurenti;
    ($nz, $nk, @konkurenti) = zjistit_moznosti_zaveseni($z, $stav);
    # Proj�t konkurenty.
    for(my $i = 0; $i<=$#konkurenti-$nk; $i++)
    {
        # Zapsat informaci o konkurentovi zp�sobem slu�iteln�m se statistikou
        # o konfliktech.
        my $konkurent;
        my $koordspojka = 1;
        if($i<$nz)
        {
            $konkurent = $stav->{uznck}[$konkurenti[$i]];
        }
        else
        {
            $konkurent = "C $stav->{uznck}[$konkurenti[$i]]";
            my $n_jako_koord = model::ud("KJJ $anot->[$konkurenti[$i+$nk]]{slovo}");
            my $n_jako_cokoli = model::ud("USS $anot->[$konkurenti[$i+$nk]]{slovo}");
            $koordspojka = $n_jako_koord/$n_jako_cokoli;
        }
        my $sila_kandidata;
        my $sila_konkurenta;
        my $vyhral_konkurent = 0;
        # Pokud je kandid�t vlevo od z�visl�ho, zaj�maj� n�s konkurenti vpravo.
        if($r<$z && $konkurenti[$i]>$z)
        {
            # Zjistit s�ly kandid�ta a konkurenta.
            my $zaznam = "LOK $stav->{uznck}[$z] L $kandidat P $konkurent";
            $sila_kandidata = model::ud("$zaznam L");
            $sila_konkurenta = model::ud("$zaznam P")*$koordspojka;
            $vyhral_konkurent = $sila_konkurenta>=2*$sila_kandidata && $sila_konkurenta>=10;
            if($vyhral_konkurent)
            {
                if($anot->[$z]{rodic_vzor}==$konkurenti[$i])
                {
                    $lk_zlepseni++;
                }
                elsif($anot->[$z]{rodic_vzor}==$r)
                {
                    $lk_zhorseni++;
                }
            }
        }
        # Pokud je kandid�t vpravo od z�visl�ho, zaj�maj� n�s konkurenti vlevo.
        elsif($r>$z && $konkurenti[$i]<$z)
        {
            # Zjistit s�ly kandid�ta a konkurenta.
            my $zaznam = "LOK $stav->{uznck}[$z] L $konkurent P $kandidat";
            $sila_kandidata = model::ud("$zaznam P");
            $sila_konkurenta = model::ud("$zaznam L")*$koordspojka;
            $vyhral_konkurent = $sila_konkurenta>=2*$sila_kandidata && $sila_konkurenta>=10;
            if($vyhral_konkurent)
            {
                if($anot->[$z]{rodic_vzor}==$konkurenti[$i])
                {
                    $lk_zlepseni++;
                }
                elsif($anot->[$z]{rodic_vzor}==$r)
                {
                    $lk_zhorseni++;
                }
            }
        }
        # Ostatn� kombinace (v�etn� toho, �e konkurent je kandid�t s�m) n�s
        # zat�m nezaj�maj�.
        else
        {
            next;
        }
        # Pokud je konkurent alespo� dvakr�t lep�� ne� kandid�t, a pokud nav�c
        # jejich srovn�n� vych�z� ze vzorku alespo� 15 v�skyt�, vybrat
        # konkurenta.
        if($vyhral_konkurent && $sila_konkurenta/($sila_konkurenta+$sila_kandidata)>$maxsila)
        {
            $maxsila = $sila_konkurenta/($sila_konkurenta+$sila_kandidata);
            $rmax = ($i<$nz) ? $konkurenti[$i] : $konkurenti[$i+$nk];
            $pristemax = $i<$nz ? "" : $konkurenti[$i+$nk]."-".$konkurenti[$i];
        }
    }
    my %navrh1 = %{$navrh0};
    $navrh1{r} = $rmax;
    $navrh1{z} = $zmax;
    if($rmax!=$navrh0->{r} || $zmax!=$navrh0->{z})
    {
        $navrh1{priste} = $pristemax;
        $navrh1{p} = $maxsila;
    }
    return %navrh1;
}



#------------------------------------------------------------------------------
# Zjist� povolen� zav�en� uzlu v�etn� koordinac�.
#------------------------------------------------------------------------------
sub zjistit_moznosti_zaveseni
{
    my $z = shift;
    my $stav = shift; # odkaz na hash se stavem anal�zy
    my $povol_z = join(",", @{$stav->{povol}}).",";
    # Zat�m glob�ln� prom�nn�.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    # Odstranit ze seznamu povolen�ch z�vislost� ty, kter� zav�uj� jin� uzel.
    $povol_z =~ s/\d+-(?!$z,)\d+,//g;
    # P�epsat seznam z�vislost� na seznam ��d�c�ch uzl�.
    $povol_z =~ s/-$z,/,/g;
    my @r = split(/,/, $povol_z);
    # Vy�adit z�vislosti, kter� jsou na �ern� listin�.
    for(my $i = 0; $i<=$#r; $i++)
    {
        if(zakaz::je_zakazana($stav->{zakaz}, $r[$i], $z))
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
    for(my $i = 0; $i<$n_zavislosti; $i++)
    {
        # ��d�c� uzel mus� b�t zn�m jako potenci�ln� koordina�n� spojka.
        my $n_jako_koord = model::ud("KJJ $anot->[$r[$i]]{slovo}");
        my $n_jako_cokoli = model::ud("USS $anot->[$r[$i]]{slovo}");
        # Koordina�n� spojka nesm� ��dit n�kolik r�zn�ch koordinac� najednou.
        if($n_jako_koord>0 && !$stav->{coord}[$r[$i]])
        {
            # Naj�t potenci�ln�ho sourozence v koordinaci.
            if($z<$r[$i])
            {
                # Pokud u� spojka m� rodi�e, a to na t� stran�, na kter�
                # hled�me sourozence, spojen� se sourozencem nen� povoleno.
                if($stav->{rodic}[$r[$i]]!=-1 && $stav->{rodic}[$r[$i]]>$r[$i])
                {
                    next;
                }
                # Naj�t dosah spojky. Sourozenec se m��e hledat a� za n�m.
                for(my $j = $r[$i]+1; $j<=$#{$anot}; $j++)
                {
                    if($stav->{rodic}[$j]==-1)
                    {
                        # Nalezen potenci�ln� sourozenec. P�idat ho do pole.
                        push(@spojky, $r[$i]);
                        push(@r, $j);
                        last;
                    }
                }
            }
            else
            {
                # Pokud u� spojka m� rodi�e, a to na t� stran�, na kter�
                # hled�me sourozence, spojen� se sourozencem nen� povoleno.
                if($stav->{rodic}[$r[$i]]!=-1 && $stav->{rodic}[$r[$i]]<$r[$i])
                {
                    next;
                }
                for(my $j = $r[$i]-1; $j>=0; $j--)
                {
                    if($stav->{rodic}[$j]==-1)
                    {
                        # Nalezen potenci�ln� sourozenec. P�idat ho do pole.
                        push(@spojky, $r[$i]);
                        push(@r, $j);
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
# Vytvo�� hl�en� na z�klad� sv�ch statistik. Nikam ho nevypisuje, jen ho vr�t�
# volaj�c�mu. Je na volaj�c�m, aby rozhodl, na kter� v�stup ho po�le.
#------------------------------------------------------------------------------
sub vytvorit_hlaseni
{
    my $hlaseni = "------- Model lok�ln�ch konflikt� -------\n";
    $hlaseni .= sprintf("%7d   zlep�en�\n", $lk_zlepseni);
    $hlaseni .= sprintf("%7d   zhor�en�\n", $lk_zhorseni);
    return $hlaseni;
}



1;
