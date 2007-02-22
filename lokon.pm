package lokon;
use utf8;
use zakaz;
use model; # jen kvůli sub ud()



#------------------------------------------------------------------------------
# Pokusí se vyřešit lokální konflikty konkurenčních zavěšení uzlu, a to na
# základě kontextu. Pravděpodobnost určitého zavěšení uzlu může být jiná, pokud
# víme, že jeho konkurencí bylo konkrétní jiné zavěšení.
#
# Vrátí odkazy na konkurenta, který zvítězil (tím může být i původní kandidát).
#------------------------------------------------------------------------------
sub lokalni_konflikty
{
    my $anot = shift; # odkaz na pole hashů
    my $navrh0 = shift; # odkaz na hash se zatím nejlepší hranou (r, z, c, p...)
    my $stav = shift; # odkaz na hash se stavem analýzy
    my $r = $navrh0->{r}; # index řídícího uzlu hrany, kterou navrhl původní model
    my $z = $navrh0->{z}; # index závislého uzlu hrany, kterou navrhl původní model
    my $priste = $navrh0->{priste}; # u koordinací: druhá polovina do příštího kola
    my @povol = @{$stav->{povol}}; # seznam momentálně povolených hran
    # Zatím globální proměnné.
    my $konfig = \%main::konfig;
    my $rmax = $r;
    my $zmax = $z;
    my $pristemax = $priste;
    my $maxsila;
    # Zapsat informaci o kandidátovi na řídícího způsobem slučitelným se
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
    my $nz; # kolik konkurentů jsou závislosti
    my $nk; # kolik konkurentů jsou koordinace (nejdřív sourozenci, pak spojky)
    my @konkurenti;
    ($nz, $nk, @konkurenti) = zjistit_moznosti_zaveseni($anot, $z, $stav);
    # Projít konkurenty.
    for(my $i = 0; $i<=$#konkurenti-$nk; $i++)
    {
        # Zapsat informaci o konkurentovi způsobem slučitelným se statistikou
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
        # Ostatní kombinace (včetně toho, že konkurent je kandidát sám) nás
        # zatím nezajímají.
        else
        {
            next;
        }
        # Pokud je konkurent alespoň dvakrát lepší než kandidát, a pokud navíc
        # jejich srovnání vychází ze vzorku alespoň 15 výskytů, vybrat
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
# Zjistí povolená zavěšení uzlu včetně koordinací.
#------------------------------------------------------------------------------
sub zjistit_moznosti_zaveseni
{
    my $anot = shift; # odkaz na pole hashů
    my $z = shift;
    my $stav = shift; # odkaz na hash se stavem analýzy
    my $povol_z = join(",", @{$stav->{povol}}).",";
    # Zatím globální proměnné.
    my $konfig = \%main::konfig;
    # Odstranit ze seznamu povolených závislostí ty, které zavěšují jiný uzel.
    $povol_z =~ s/\d+-(?!$z,)\d+,//g;
    # Přepsat seznam závislostí na seznam řídících uzlů.
    $povol_z =~ s/-$z,/,/g;
    my @r = split(/,/, $povol_z);
    # Vyřadit závislosti, které jsou na černé listině.
    for(my $i = 0; $i<=$#r; $i++)
    {
        if(zakaz::je_zakazana($stav->{zakaz}, $r[$i], $z))
        {
            splice(@r, $i, 1);
            $i--;
        }
    }
    # Uspořádat konkurenční závislosti podle vzdálenosti řídícího uzlu od
    # závislého. Pokud se analyzátor rozhodne skončit u prvního konkurenta,
    # který předčí původního kandidáta, bude zajištěno, že dostane nejkratší
    # takové zavěšení.
    $povol_z = join(",", sort{abs($a-$z)<=>abs($b-$z);}(split(/,/, $povol_z)))
    .",";
    # Zapamatovat si počet opravdových závislostí, aby je volající mohl odlišit
    # od koordinací.
    my $n_zavislosti = $#r+1;
    # Projít řídící uzly a přidat potenciální koordinace.
    my @spojky;
    for(my $i = 0; $i<$n_zavislosti; $i++)
    {
        # Řídící uzel musí být znám jako potenciální koordinační spojka.
        my $n_jako_koord = model::ud("KJJ $anot->[$r[$i]]{slovo}");
        my $n_jako_cokoli = model::ud("USS $anot->[$r[$i]]{slovo}");
        # Koordinační spojka nesmí řídit několik různých koordinací najednou.
        if($n_jako_koord>0 && !$stav->{coord}[$r[$i]])
        {
            # Najít potenciálního sourozence v koordinaci.
            if($z<$r[$i])
            {
                # Pokud už spojka má rodiče, a to na té straně, na které
                # hledáme sourozence, spojení se sourozencem není povoleno.
                if($stav->{rodic}[$r[$i]]!=-1 && $stav->{rodic}[$r[$i]]>$r[$i])
                {
                    next;
                }
                # Najít dosah spojky. Sourozenec se může hledat až za ním.
                for(my $j = $r[$i]+1; $j<=$#{$anot}; $j++)
                {
                    if($stav->{rodic}[$j]==-1)
                    {
                        # Nalezen potenciální sourozenec. Přidat ho do pole.
                        push(@spojky, $r[$i]);
                        push(@r, $j);
                        last;
                    }
                }
            }
            else
            {
                # Pokud už spojka má rodiče, a to na té straně, na které
                # hledáme sourozence, spojení se sourozencem není povoleno.
                if($stav->{rodic}[$r[$i]]!=-1 && $stav->{rodic}[$r[$i]]<$r[$i])
                {
                    next;
                }
                for(my $j = $r[$i]-1; $j>=0; $j--)
                {
                    if($stav->{rodic}[$j]==-1)
                    {
                        # Nalezen potenciální sourozenec. Přidat ho do pole.
                        push(@spojky, $r[$i]);
                        push(@r, $j);
                        last;
                    }
                }
            }
        }
    }
    # Vrátit počet závislostí a počet koordinací, následovaný polem závislostí,
    # polem koordinací a polem spojek.
    return($n_zavislosti, $#r-$n_zavislosti+1, @r, @spojky);
}



#------------------------------------------------------------------------------
# Vytvoří hlášení na základě svých statistik. Nikam ho nevypisuje, jen ho vrátí
# volajícímu. Je na volajícím, aby rozhodl, na který výstup ho pošle.
#------------------------------------------------------------------------------
sub vytvorit_hlaseni
{
    my $hlaseni = "------- Model lokálních konfliktů -------\n";
    $hlaseni .= sprintf("%7d   zlepšení\n", $lk_zlepseni);
    $hlaseni .= sprintf("%7d   zhoršení\n", $lk_zhorseni);
    return $hlaseni;
}



1;
