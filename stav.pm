package stav;
use zakaz;



#------------------------------------------------------------------------------
# Pøidá do stromu závislost a aktualizuje stromové globální promìnné.
#------------------------------------------------------------------------------
sub pridat_zavislost
{
    my $stav = shift; # odkaz na hash
    my $kandidat = shift; # odkaz na hash s polo¾kami r, z, c a p
    # Tahle èást se døíve provádìla u¾ na konci funkce generovat_stavy(), proto
    # ji provést nejdøíve.
    # Pokud se pøidává èást koordinace, zajistit návaznost v pøí¹tích kolech.
    if($kandidat->{priste} ne "" && $stav->{coord}[$kandidat->{r}]!=1)
    {
        $stav->{coord}[$kandidat->{r}] = 1;
        # Pokud budujeme koordinaci, musíme zajistit, aby ¹la celá nìkam
        # povìsit. Její koøen tedy musí vìdìt, jakého druhu jsou èlenové.
        # Zapamatovat si, po kom má koøen koordinace "zdìdit" slovní druh a pád.
        $stav->{dedic}[$kandidat->{r}] = $kandidat->{z};
        $stav->{uznck}[$kandidat->{r}] = $stav->{uznck}[$kandidat->{z}];
    }
    $stav->{priste} = $kandidat->{priste};
    # Kvùli ladìní si zapamatovat seznam povolených závislostí, ze kterého byla vybrána ta na¹e.
    $stav->{vyber}[$kandidat->{z}] = join(",", $stav->{povol});
    $stav->{rodic}[$kandidat->{z}] = $kandidat->{r};
    $stav->{ndeti}[$kandidat->{r}]++;
    $stav->{zbyva}--;
    $stav->{nprid}++;
    $stav->{maxc}[$kandidat->{z}] = $kandidat->{c};
    $stav->{maxp}[$kandidat->{z}] = $kandidat->{p};
    $stav->{pord}[$kandidat->{z}] = $stav->{nprid}; # Poøadí, kolikátý byl zvolen.
    # Zapamatovat si, kdo byl pøidán jako poslední, aby se to nemuselo hledat procházením {pord}.
    $stav->{poslz} = $kandidat->{z};
    zakaz::prehodnotit_zakazy($stav, $kandidat->{r}, $kandidat->{z});
}



#------------------------------------------------------------------------------
# Odstraní ze stromu závislost a aktualizuje stromové globální promìnné.
#------------------------------------------------------------------------------
sub zrusit_zavislost
{
    my $stav = shift; # odkaz na hash
    my $z = shift; # index závislého uzlu pøidávané závislosti
    my $r = $stav->{rodic}[$z];
    return -1 if($r==-1);
    # Kvùli ladìní jsme si pamatovali seznam povolených závislostí, ze kterého byla vybrána ta na¹e.
    $stav->{vyber}[$z] = "";
    $stav->{rodic}[$z] = -1;
    $stav->{ndeti}[$r]--;
    $stav->{zbyva}++;
    $stav->{nprid}--;
    $stav->{poslz} = -1 if($stav->{poslz}==$z);
}



#------------------------------------------------------------------------------
# Ulo¾í rozpracovaný strom i se v¹emi doplòujícími informacemi, aby se k nìmu
# bylo mo¾né kdykoliv vrátit. Vrátí odkaz na ulo¾enou kopii stavu analýzy.
#------------------------------------------------------------------------------
sub zduplikovat
{
    my $stav = shift; # odkaz na stav analýzy
    # Zkopírovat hodnoty stavu, aby nebyly dotèeny dal¹ími zmìnami stavu u volajícího.
    # Kopírovat se musí hloubkovì, tj. ne odkazy na pole uvnitø stavu, ale celé kopie polí!
    return zduplikovat_hash($stav);
}



#------------------------------------------------------------------------------
# Vytvoøí hloubkovou kopii pole.
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
# Vytvoøí hloubkovou kopii hashe.
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
