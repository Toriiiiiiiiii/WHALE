struc str [data] 
{
    common
    .text db data
    .size = $-.text
}
