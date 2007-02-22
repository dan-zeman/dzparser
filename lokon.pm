package lokon;
use zakaz;
use model; # jen kvùli sub ud()



#------------------------------------------------------------------------------
# Pokusí se vyøe¹it lokální konflikty konkurenèních zavì¹ení uzlu, a to na
# základì kontextu. Pravdìpodobnost urèitého zavì¹ení uzlu mù¾e být jiná, pokud
# víme, ¾e jeho konkurencí bylo konkrétní jiné zavì¹ení.
#
# Vrátí odkazy na konkurenta, který zvítìzil (tím mù¾e být i pùvodní kandidát).
#------------------------------------------------------------------------------
sub lokalni_konflikty
{
    my $navrh0 = shift; # odkaz na hash se zatím nejlep¹í hranou (r, z, c, p...)
    my $stav = shift; # odkaz na hash se stavem analýzy
    my $r = $navrh0->{r}; # index øídícího uzlu hrany, kterou navrhl pùvodní model
    my $z = $navrh0->{z}; # index závislého uzlu hrany, kterou navrhl pùvodní model
    my $priste = $navrh0->{priste}; # u koordinací: druhá polovina do pøí¹tího kola
    my @povol = @{$stav->{povol}}; # seznam momentálnì povolených hran
    # Zatím globální promìnné.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    my $rmax = $r;
    my $zmax = $z;
    my $pristemax = $priste;
    my $maxsila;
    # Zapsat informaci o kandidátovi na øídícího zpùsobem sluèitelným se
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
    my $nz; # kolik konkurentù jsou závislosti
    my $nk; # kolik konkurentù jsou koordinace (nejdøív sourozenci, pak spojky)
    my @konkurenti;
    ($nz, $nk, @konkurenti) = zjistit_moznosti_zaveseni($z, $stav);
    # Projít konkurenty.
    for(my $i = 0; $i<=$#konkurenti-$nk; $i++)
    {
        # Zapsat informaci o konkurentovi zpùsobem sluèitelným se statistikou
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
        # Pokud je kandidát vlevo od závislého, zajímají nás konkurenti vpravo.
        if($r<$z && $konkurenti[$i]>$z)
        {
            # Zjistit síly kandidáta a konkurenta.
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
        # Pokud je kandidát vpravo od závislého, zajímají nás konkurenti vlevo.
        elsif($r>$z && $konkurenti[$i]<$z)
        {
            # Zjistit síly kandidáta a konkurenta.
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
        # Ostatní kombinace (vèetnì toho, ¾e konkurent je kandidát sám) nás
        # zatím nezajímají.
        else
        {
            next;
        }
        # Pokud je konkurent alespoò dvakrát lep¹í ne¾ kandidát, a pokud navíc
        # jejich srovnání vychází ze vzorku alespoò 15 výskytù, vybrat
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
# Zjistí povolená zavì¹ení uzlu vèetnì koordinací.
#------------------------------------------------------------------------------
sub zjistit_moznosti_zaveseni
{
    my $z = shift;
    my $stav = shift; # odkaz na hash se stavem analýzy
    my $povol_z = join(",", @{$stav->{povol}}).",";
    # Zatím globální promìnné.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    # Odstranit ze seznamu povolených závislostí ty, které zavì¹ují jiný uzel.
    $povol_z =~ s/\d+-(?!$z,)\d+,//g;
    # Pøepsat seznam závislostí na seznam øídících uzlù.
    $povol_z =~ s/-$z,/,/g;
    my @r = split(/,/, $povol_z);
    # Vyøadit závislosti, které jsou na èerné listinì.
    for(my $i = 0; $i<=$#r; $i++)
    {
        if(zakaz::je_zakazana($stav->{zakaz}, $r[$i], $z))
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
    for(my $i = 0; $i<$n_zavislosti; $i++)
    {
        # Øídící uzel musí být znám jako potenciální koordinaèní spojka.
        my $n_jako_koord = model::ud("KJJ $anot->[$r[$i]]{slovo}");
        my $n_jako_cokoli = model::ud("USS $anot->[$r[$i]]{slovo}");
        # Koordinaèní spojka nesmí øídit nìkolik rùzných koordinací najednou.
        if($n_jako_koord>0 && !$stav->{coord}[$r[$i]])
        {
            # Najít potenciálního sourozence v koordinaci.
            if($z<$r[$i])
            {
                # Pokud u¾ spojka má rodièe, a to na té stranì, na které
                # hledáme sourozence, spojení se sourozencem není povoleno.
                if($stav->{rodic}[$r[$i]]!=-1 && $stav->{rodic}[$r[$i]]>$r[$i])
                {
                    next;
                }
                # Najít dosah spojky. Sourozenec se mù¾e hledat a¾ za ním.
                for(my $j = $r[$i]+1; $j<=$#{$anot}; $j++)
                {
                    if($stav->{rodic}[$j]==-1)
                    {
                        # Nalezen potenciální sourozenec. Pøidat ho do pole.
                        push(@spojky, $r[$i]);
                        push(@r, $j);
                        last;
                    }
                }
            }
            else
            {
                # Pokud u¾ spojka má rodièe, a to na té stranì, na které
                # hledáme sourozence, spojení se sourozencem není povoleno.
                if($stav->{rodic}[$r[$i]]!=-1 && $stav->{rodic}[$r[$i]]<$r[$i])
                {
                    next;
                }
                for(my $j = $r[$i]-1; $j>=0; $j--)
                {
                    if($stav->{rodic}[$j]==-1)
                    {
                        # Nalezen potenciální sourozenec. Pøidat ho do pole.
                        push(@spojky, $r[$i]);
                        push(@r, $j);
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
# Vytvoøí hlá¹ení na základì svých statistik. Nikam ho nevypisuje, jen ho vrátí
# volajícímu. Je na volajícím, aby rozhodl, na který výstup ho po¹le.
#------------------------------------------------------------------------------
sub vytvorit_hlaseni
{
    my $hlaseni = "------- Model lokálních konfliktù -------\n";
    $hlaseni .= sprintf("%7d   zlep¹ení\n", $lk_zlepseni);
    $hlaseni .= sprintf("%7d   zhor¹ení\n", $lk_zhorseni);
    return $hlaseni;
}



1;
