package stav;
use zakaz;



#------------------------------------------------------------------------------
# P�id� do stromu z�vislost a aktualizuje stromov� glob�ln� prom�nn�.
#------------------------------------------------------------------------------
sub pridat_zavislost
{
    my $stav = shift; # odkaz na hash
    my $kandidat = shift; # odkaz na hash s polo�kami r, z, c a p
    # Tahle ��st se d��ve prov�d�la u� na konci funkce generovat_stavy(), proto
    # ji prov�st nejd��ve.
    # Pokud se p�id�v� ��st koordinace, zajistit n�vaznost v p��t�ch kolech.
    if($kandidat->{priste} ne "" && $stav->{coord}[$kandidat->{r}]!=1)
    {
        $stav->{coord}[$kandidat->{r}] = 1;
        # Pokud budujeme koordinaci, mus�me zajistit, aby �la cel� n�kam
        # pov�sit. Jej� ko�en tedy mus� v�d�t, jak�ho druhu jsou �lenov�.
        # Zapamatovat si, po kom m� ko�en koordinace "zd�dit" slovn� druh a p�d.
        $stav->{dedic}[$kandidat->{r}] = $kandidat->{z};
        $stav->{uznck}[$kandidat->{r}] = $stav->{uznck}[$kandidat->{z}];
    }
    $stav->{priste} = $kandidat->{priste};
    # Kv�li lad�n� si zapamatovat seznam povolen�ch z�vislost�, ze kter�ho byla vybr�na ta na�e.
    $stav->{vyber}[$kandidat->{z}] = join(",", $stav->{povol});
    $stav->{rodic}[$kandidat->{z}] = $kandidat->{r};
    $stav->{ndeti}[$kandidat->{r}]++;
    $stav->{zbyva}--;
    $stav->{nprid}++;
    $stav->{maxc}[$kandidat->{z}] = $kandidat->{c};
    $stav->{maxp}[$kandidat->{z}] = $kandidat->{p};
    $stav->{pord}[$kandidat->{z}] = $stav->{nprid}; # Po�ad�, kolik�t� byl zvolen.
    # Zapamatovat si, kdo byl p�id�n jako posledn�, aby se to nemuselo hledat proch�zen�m {pord}.
    $stav->{poslz} = $kandidat->{z};
    zakaz::prehodnotit_zakazy($stav, $kandidat->{r}, $kandidat->{z});
}



#------------------------------------------------------------------------------
# Odstran� ze stromu z�vislost a aktualizuje stromov� glob�ln� prom�nn�.
#------------------------------------------------------------------------------
sub zrusit_zavislost
{
    my $stav = shift; # odkaz na hash
    my $z = shift; # index z�visl�ho uzlu p�id�van� z�vislosti
    my $r = $stav->{rodic}[$z];
    return -1 if($r==-1);
    # Kv�li lad�n� jsme si pamatovali seznam povolen�ch z�vislost�, ze kter�ho byla vybr�na ta na�e.
    $stav->{vyber}[$z] = "";
    $stav->{rodic}[$z] = -1;
    $stav->{ndeti}[$r]--;
    $stav->{zbyva}++;
    $stav->{nprid}--;
    $stav->{poslz} = -1 if($stav->{poslz}==$z);
}



#------------------------------------------------------------------------------
# Ulo�� rozpracovan� strom i se v�emi dopl�uj�c�mi informacemi, aby se k n�mu
# bylo mo�n� kdykoliv vr�tit. Vr�t� odkaz na ulo�enou kopii stavu anal�zy.
#------------------------------------------------------------------------------
sub zduplikovat
{
    my $stav = shift; # odkaz na stav anal�zy
    # Zkop�rovat hodnoty stavu, aby nebyly dot�eny dal��mi zm�nami stavu u volaj�c�ho.
    # Kop�rovat se mus� hloubkov�, tj. ne odkazy na pole uvnit� stavu, ale cel� kopie pol�!
    return zduplikovat_hash($stav);
}



#------------------------------------------------------------------------------
# Vytvo�� hloubkovou kopii pole.
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
# Vytvo�� hloubkovou kopii hashe.
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
