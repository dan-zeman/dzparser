package vyhodnoceni;
use utf8;
use vystupy;
use lokon;
use ntice;
use model;



$prah_verohodnosti = 10;



#------------------------------------------------------------------------------
# Vypíše výsledky vyhodnocení.
#------------------------------------------------------------------------------
sub vypsat
{
    my $hodnoceni = shift;
    # Slovní úspěšnost.
    my $g = $hodnoceni->{spravne};
    my $b = $hodnoceni->{spatne};
    my $n = $hodnoceni->{celkem} = $g+$b;
    my $p = $g/$n if($n);
    vystupy::vypsat("vysledky", "----------------------------------------\n");
    vystupy::vypsat("vysledky", "A $n - G $g - B $b - P $p\n");
    vystupy::vypsat("vysledky", "----------------------------------------\n");
    # Slovní úspěšnost rozepsaná podle délky věty.
    for(my $i = 1; $i<=$#{$hodnoceni->{celkem_podle_delky_vety}}; $i++)
    {
        if($hodnoceni->{spravne_podle_delky_vety}[$i])
        {
            my $g = $hodnoceni->{spravne_podle_delky_vety}[$i];
            my $n = $hodnoceni->{celkem_podle_delky_vety}[$i];
            my $p = $g/$n if($n);
            my $nvet = $n/$i;
            vystupy::vypsat("vysledky", "Slovní úspěšnost - $nvet vět délky $i: A $n - G $g - P $p\n");
        }
    }
    vystupy::vypsat("vysledky", "----------------------------------------\n");
    # Dílčí úspěšnost zavěšení uzlů s vybranými s-značkami.
    $g = $hodnoceni->{vyber_spravne};
    $b = $hodnoceni->{vyber_spatne};
    $n = $g+$b;
    $p = $g/$n if($n);
    vystupy::vypsat("vysledky", "A $n - G $g - B $b - P $p ($main::konfig{testafun})\n");
    # Dílčí úspěšnost zpracování lokálních konfliktů.
    vystupy::vypsat("vysledky", "----------------------------------------\n");
    vystupy::vypsat("vysledky", lokon::vytvorit_hlaseni());
    vystupy::vypsat("vysledky", "----------------------------------------\n");
    # Srovnání stromové pravděpodobnosti vzorových a navrhovaných stromů.
    vystupy::vypsat("vysledky", "$hodnoceni->{vzor_lepsi_nez_navrh}× měl vzorový strom VYŠŠÍ pravděpodobnost než navrhovaný.\n");
    vystupy::vypsat("vysledky", "$hodnoceni->{vzor_horsi_nez_navrh}× měl vzorový strom NIŽŠÍ pravděpodobnost než navrhovaný.\n");
    vystupy::vypsat("vysledky", "$hodnoceni->{vzor_stejny_jako_navrh}× měl vzorový strom STEJNOU pravděpodobnost jako navrhovaný.\n");
    vystupy::vypsat("vysledky", "Vybráno $hodnoceni->{nuly_navrh}/$hodnoceni->{nuly_vzor} závislostí s nulovou pravděpodobností.\n");
    # Dílčí úspěšnost modelu n-tic.
    vystupy::vypsat("vysledky", ntice::vytvorit_hlaseni()) if($main::konfig{ntice});
    # Větná úspěšnost.
    vystupy::vypsat("vysledky", "----------------------------------------\n");
    $g = $hodnoceni->{spravne_vety};
    $n = $hodnoceni->{vety};
    $p = $g/$n if($n);
    vystupy::vypsat("vysledky", "Věty: A $n - G $g - P $p\n");
    $g = $hodnoceni->{slova_ve_spravnych_vetach};
    $n = $hodnoceni->{spravne}+$hodnoceni->{spatne};
    $p = $g/$n if($n);
    vystupy::vypsat("vysledky", "Správná jsou jen slova ve 100% větách: A $n - G $g - P $p\n");
    # Větná úspěšnost rozepsaná podle délky věty.
    vystupy::vypsat("vysledky", "----------------------------------------\n");
    for(my $i = 1; $i<=$#{$hodnoceni->{vety_podle_delky}}; $i++)
    {
        if($hodnoceni->{spravne_vety_podle_delky}[$i])
        {
            my $g = $hodnoceni->{spravne_vety_podle_delky}[$i];
            my $n = $hodnoceni->{vety_podle_delky}[$i];
            my $p = $g/$n if($n);
            vystupy::vypsat("vysledky", "Větná úspěšnost - věty délky $i: A $n - G $g - P $p\n");
        }
    }
    vystupy::vypsat("vysledky", "----------------------------------------\n");
    # Slovní úspěšnost vážená obtížností podle délky věty.
    $g = $hodnoceni->{spravne_vazeno_obtiznosti};
    $n = $hodnoceni->{celkem_vazeno_obtiznosti};
    $p = $g/$n if($n);
    vystupy::vypsat("vysledky", "VAZENO OBTIZNOSTI: A $n - G $g - P $p\n");
    # (Nemá smysl rozepisovat totéž podle délky věty, protože úspěšnost by byla stejná jako nevážená.)
    # Hodnocení jen závislostí, které byly v trénovacích datech vidět pět- a vícekrát.
    $g = $hodnoceni->{spravne_5_a_vice};
    $n = $g+$hodnoceni->{spatne_5_a_vice};
    $p = $g/$n if($n);
    my $r = $g/$hodnoceni->{celkem} if($hodnoceni->{celkem});
    my $f = $p+$r==0 ? 0 : 2*$p*$r/($p+$r);
    vystupy::vypsat("vysledky", "VIDENO $prah_verohodnosti+ KRAT: AA $hodnoceni->{celkem} - A $n - G $g - P $p - R $r - F $f\n");
    # Vyhodnotit alternativní závislosti.
    $g = $hodnoceni->{altzav_spravne};
    $b = $hodnoceni->{altzav_spatne};
    vystupy::vypsat("vysledky", "ALTZAV G $g - B $b\n");
    $g += $hodnoceni->{spravne};
    $b += $hodnoceni->{spatne};
    my $a = $hodnoceni->{celkem};
    $n = $g+$b;
    $p = $n==0 ? 0 : $g/$n;
    $r = $a==0 ? 0 : $g/$a;
    $f = $p+$r==0 ? 0 : 2*$p*$r/($p+$r);
    vystupy::vypsat("vysledky", "ALT+NORM AA $a - A $n - G $g - P $p - R $r - F $f\n");
    # Vypsat úspěšnost podle jednotlivých s-značek (afunů).
    my @klice = sort(keys(%{$hodnoceni->{celkem_afun}}));
    foreach my $klic (@klice)
    {
        my $g = $hodnoceni->{spravne_afun}{$klic};
        my $n = $hodnoceni->{celkem_afun}{$klic};
        my $p = $g/$n if($n);
        vystupy::vypsat("vysledky", "Pouze uzly oznacene $klic: A $n - G $g - P $p\n");
    }
    # Vypsat úspěšnost pro každou stovku vět zvlášť.
    if(0)
    {
          for(my $i = 0; $i<=$#{$hodnoceni->{celkem_100vet}}; $i++)
          {
              my $g = $hodnoceni->{spravne_100vet}[$i];
              my $n = $hodnoceni->{celkem_100vet}[$i];
              my $p = $g/$n if($n);
              vystupy::vypsat("vysledky", "$p\n");
          }
    }
}



#------------------------------------------------------------------------------
# Ověří shodu závislostí ve stromě se závislostmi ve vzorovém stromě.
#------------------------------------------------------------------------------
sub zkontrolovat_strom
{
    my $anot = shift; # odkaz na pole hashů
    my $stav = shift; # odkaz na koncový stav analýzy
    my $hodnoceni = shift; # odkaz na hash, do kterého lze zaznamenávat hodnocení
    my $navrh = $stav->{rodic};
    # Zatím globální proměnné.
    my $konfig = \%main::konfig;
    my $n_slov = $#{$anot};
    # Vynulovat hodnocení vztahující se pouze k poslednímu stromu.
    $hodnoceni->{spravne_posledni_strom} = 0;
    $hodnoceni->{spatne_posledni_strom} = 0;
    $hodnoceni->{celkem_posledni_strom} = $n_slov;
    $hodnoceni->{uspesnost_posledni_strom} = 0;
    # Zvláštní hodnocení vztahující se ke každým 100 větám.
    $hodnoceni->{i_veta}++;
    # Pravděpodobnosti celých stromů pomůžou vyhodnotit, zda by něco dokázal backtracking.
    my $pstrom_vzor = 1;
    my $pstrom_navrh = 1;
    # Projít větu a porovnávat navrhované závislosti se vzorovými.
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        my $z = $i; # index závislého uzlu
        my $rvzo = $anot->[$i]{rodic_vzor}; # index řídícího uzlu podle vzorové anotace
        my $rnav = $navrh->[$i]; # index řídícího uzlu navržený parserem
        # Přidat pravděpodobnost závislosti do pravděpodobnosti stromu.
        my ($p, $c) = model::zjistit_nezkreslenou_pravdepodobnost($anot, $rvzo, $z);
        if($c==0)
        {
            $hodnoceni->{nuly_vzor}++;
        }
        $pstrom_vzor *= $p;
        ($p, $c) = model::zjistit_nezkreslenou_pravdepodobnost($anot, $rnav, $z, $stav);
        if($c==0)
        {
            $hodnoceni->{nuly_navrh}++;
        }
        $pstrom_navrh *= $p;
        # Porovnat navrženou závislost se vzorovou.
        $hodnoceni->{celkem_afun}{$anot->[$i]{afun}}++;
        $hodnoceni->{celkem_100vet}[int($hodnoceni->{i_veta}/100)]++;
        if($rnav==$rvzo)
        {
            $hodnoceni->{spravne}++;
            $hodnoceni->{spravne_posledni_strom}++;
            $hodnoceni->{spravne_afun}{$anot->[$i]{afun}}++;
            $hodnoceni->{spravne_100vet}[int($hodnoceni->{i_veta}/100)]++;
            if($anot->[$i]{afun}=~m/^($konfig->{"testafun"})$/)
            {
                $hodnoceni->{vyber_spravne}++;
            }
            if($c>=$prah_verohodnosti)
            {
                $hodnoceni->{spravne_5_a_vice}++;
            }
        }
        else
        {
            $hodnoceni->{spatne}++;
            $hodnoceni->{spatne_posledni_strom}++;
            if($anot->[$i]{afun}=~m/^($konfig->{"testafun"})$/)
            {
                $hodnoceni->{vyber_spatne}++;
            }
            if($c>=$prah_verohodnosti)
            {
                $hodnoceni->{spatne_5_a_vice}++;
            }
        }
    }
    # Porovnat stromové pravděpodobnosti vzorového a navrhovaného stromu.
    if($pstrom_vzor>$pstrom_navrh)
    {
        $hodnoceni->{vzor_lepsi_nez_navrh}++;
    }
    elsif($pstrom_vzor<$pstrom_navrh)
    {
        $hodnoceni->{vzor_horsi_nez_navrh}++;
    }
    else
    {
        $hodnoceni->{vzor_stejny_jako_navrh}++;
    }
    # Ladění: Zkontrolovat, zda správně zjišťujeme počet slov ve větě.
    if($n_slov!=$hodnoceni->{spravne_posledni_strom}+$hodnoceni->{spatne_posledni_strom})
    {
        die("Chybne zjisteny pocet slov ve vete: $n_slov != $hodnoceni->{spravne_posledni_strom}+$hodnoceni->{spatne_posledni_strom}\n");
    }
    $hodnoceni->{uspesnost_posledni_strom} = $n_slov>0 ? $hodnoceni->{spravne_posledni_strom}/$n_slov : 0;
    # Zapamatovat si odděleně úspěšnost na větách různé délky.
    $hodnoceni->{spravne_podle_delky_vety}[$n_slov] += $hodnoceni->{spravne_posledni_strom};
    $hodnoceni->{celkem_podle_delky_vety}[$n_slov] += $n_slov;
    # Zjistit úspěšnost na větách.
    $hodnoceni->{vety}++;
    $hodnoceni->{vety_podle_delky}[$n_slov]++;
    if($hodnoceni->{uspesnost_posledni_strom}==1)
    {
        $hodnoceni->{spravne_vety}++;
        $hodnoceni->{slova_ve_spravnych_vetach} += $n_slov;
        # Zapamatovat si správné věty i zvlášť podle délky.
        $hodnoceni->{spravne_vety_podle_delky}[$n_slov]++;
    }
    # Zjistit obtížnost zavěšování slov v tomto stromě (odvozuje se od délky věty).
    my $obtiznost;
    if($n_slov)
    {
        $obtiznost = 1-(1/$n_slov);
    }
    else
    {
        vypsat("prubeh", "Varování: Prázdná věta!\n");
        $obtiznost = 0;
    }
    $hodnoceni->{spravne_vazeno_obtiznosti} += $obtiznost*$hodnoceni->{spravne_posledni_strom};
    $hodnoceni->{celkem_vazeno_obtiznosti} += $obtiznost*$n_slov;
    # Projít pole alternativních závislostí, vynechat ty, které nakonec skutečně vyhrály (ty musíme spočítat samostatně)
    # a započítat je do P a R.
    for(my $r = 0; $r<=$#{$stav->{altzav}}; $r++)
    {
        for(my $z = 0; $z<=$#{$stav->{altzav}[$r]}; $z++)
        {
            if($stav->{altzav}[$r][$z] && $navrh->[$z]!=$r)
            {
                if($anot->[$z]{rodic_vzor}==$r)
                {
                    $hodnoceni->{altzav_spravne}++;
                }
                else
                {
                    $hodnoceni->{altzav_spatne}++;
                }
            }
        }
    }
}



1;
