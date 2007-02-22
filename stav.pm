package stav;
use utf8;
use zakaz;



#------------------------------------------------------------------------------
# Přidá do stromu závislost a aktualizuje stromové globální proměnné.
#------------------------------------------------------------------------------
sub pridat_zavislost
{
    my $anot = shift; # odkaz na pole hashů
    my $stav = shift; # odkaz na hash
    my $kandidat = shift; # odkaz na hash s položkami r, z, c a p
    # Tahle část se dříve prováděla už na konci funkce generovat_stavy(), proto
    # ji provést nejdříve.
    # Pokud se přidává část koordinace, zajistit návaznost v příštích kolech.
    if($kandidat->{priste} ne "" && $stav->{coord}[$kandidat->{r}]!=1)
    {
        $stav->{coord}[$kandidat->{r}] = 1;
        # Pokud budujeme koordinaci, musíme zajistit, aby šla celá někam
        # pověsit. Její kořen tedy musí vědět, jakého druhu jsou členové.
        # Zapamatovat si, po kom má kořen koordinace "zdědit" slovní druh a pád.
        $stav->{dedic}[$kandidat->{r}] = $kandidat->{z};
        $stav->{uznck}[$kandidat->{r}] = $stav->{uznck}[$kandidat->{z}];
    }
    $stav->{priste} = $kandidat->{priste};
    # Kvůli ladění si zapamatovat seznam povolených závislostí, ze kterého byla vybrána ta naše.
    $stav->{vyber}[$kandidat->{z}] = join(",", $stav->{povol});
    $stav->{rodic}[$kandidat->{z}] = $kandidat->{r};
    $stav->{ndeti}[$kandidat->{r}]++;
    $stav->{zbyva}--;
    $stav->{nprid}++;
    $stav->{maxc}[$kandidat->{z}] = $kandidat->{c};
    $stav->{maxp}[$kandidat->{z}] = $kandidat->{p};
    $stav->{pord}[$kandidat->{z}] = $stav->{nprid}; # Pořadí, kolikátý byl zvolen.
    # Zapamatovat si, kdo byl přidán jako poslední, aby se to nemuselo hledat procházením {pord}.
    $stav->{poslz} = $kandidat->{z};
    zakaz::prehodnotit_zakazy($anot, $stav, $kandidat->{r}, $kandidat->{z});
}



#------------------------------------------------------------------------------
# Odstraní ze stromu závislost a aktualizuje stromové globální proměnné.
#------------------------------------------------------------------------------
sub zrusit_zavislost
{
    my $stav = shift; # odkaz na hash
    my $z = shift; # index závislého uzlu přidávané závislosti
    my $r = $stav->{rodic}[$z];
    return -1 if($r==-1);
    # Kvůli ladění jsme si pamatovali seznam povolených závislostí, ze kterého byla vybrána ta naše.
    $stav->{vyber}[$z] = "";
    $stav->{rodic}[$z] = -1;
    $stav->{ndeti}[$r]--;
    $stav->{zbyva}++;
    $stav->{nprid}--;
    $stav->{poslz} = -1 if($stav->{poslz}==$z);
}



#------------------------------------------------------------------------------
# Uloží rozpracovaný strom i se všemi doplňujícími informacemi, aby se k němu
# bylo možné kdykoliv vrátit. Vrátí odkaz na uloženou kopii stavu analýzy.
#------------------------------------------------------------------------------
sub zduplikovat
{
    my $stav = shift; # odkaz na stav analýzy
    # Zkopírovat hodnoty stavu, aby nebyly dotčeny dalšími změnami stavu u volajícího.
    # Kopírovat se musí hloubkově, tj. ne odkazy na pole uvnitř stavu, ale celé kopie polí!
    return zduplikovat_hash($stav);
}



#------------------------------------------------------------------------------
# Vytvoří hloubkovou kopii pole.
#------------------------------------------------------------------------------
sub zduplikovat_pole
{
    my $pole = shift;
    my @duplikat;
    for(my $i = 0; $i<=$#{$pole}; $i++)
    {
        if(ref($pole->[$i]) eq "ARRAY")
        {
            $duplikat[$i] = zduplikovat_pole($pole->[$i]);
        }
        elsif(ref($pole->[$i]) eq "HASH")
        {
            $duplikat[$i] = zduplikovat_hash($pole->[$i]);
        }
        else
        {
            $duplikat[$i] = $pole->[$i];
        }
    }
    return \@duplikat;
}



#------------------------------------------------------------------------------
# Vytvoří hloubkovou kopii hashe.
#------------------------------------------------------------------------------
sub zduplikovat_hash
{
    my $hash = shift;
    my %duplikat;
    while(my ($klic, $hodnota) = each(%{$hash}))
    {
        if(ref($hodnota) eq "ARRAY")
        {
            $duplikat{$klic} = zduplikovat_pole($hodnota);
        }
        elsif(ref($hodnota) eq "HASH")
        {
            $duplikat{$klic} = zduplikovat_hash($hodnota);
        }
        else
        {
            $duplikat{$klic} = $hodnota;
        }
    }
    return \%duplikat;
}



1;
