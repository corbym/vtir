{
This is part of Vortex Tracker II project
(c)2000-2024 S.V.Bulba
Author Sergey Bulba
E-mail: svbulba@gmail.com
Support page: http://bulba.untergrund.net/
}

unit ice;

{$mode ObjFPC}{$H+}

interface

uses
 Classes, SysUtils;

 //The algorithm was studied from the original PACKICE version 2.35 MC68000 code
 //simulated in C by Benjamin Gerard

const
 //errors
 ICE_NOERROR = 0;
 ICE_UNPACKABLETOOLONG = -1;
 //number of copied bytes too big to encode due format limitation
 ICE_NOROOM = -2; //no room to drop next byte to destination buffer

type
 //ice_packer Result structure
 TICEPackerResult = record
   case boolean of
     False: (ErrorPos, ErrorCode: integer);
     True: (ArchiveSize: int64);
 end;

function ice_packer(dstbuf: pbyte; dstsz: integer; srcbuf: pbyte;
 srcsz: integer): TICEPackerResult;

implementation

const
 ICE_HEADER = $49434521; // 'ICE!'

 //format limitation related consts
 ICE_MAXCOPYBYTES = $810d; //max number of copied bytes which can be encoded
 ICE_MAXLENGTH = $409; // max number of same bytes in sequence or max string length
 ICE_MAXOFFSET_2 = $23f; //max offset to 2 bytes length same string
 ICE_MAXOFFSET_MORE = $111f; //max offset to long same string

 //optimization
 ICE_OPTIMIZE = $1580; //optimal range for string search

function ice_packer(dstbuf: pbyte; dstsz: integer; srcbuf: pbyte;
 srcsz: integer): TICEPackerResult;
var
 srccur: pbyte; //points to current byte in srcbuf or to first byte of sample string or of same bytes sequence
 srcend: pbyte; //points to a byte after srcbuf (or to current byte if error <> ICE_NOERROR)
 dstcur: pbyte; //points to current byte in dstbuf (i.e. where to write next byte)
 dstend: pbyte; //points to a byte after dstbuf
 srcmaxsearch: pbyte; //points to a byte after src search range
 srccursearch: pbyte; //points to next byte in src search range
 srcstrend: pbyte; //points to a byte after src sample string
 srcstrsearchbegin: pbyte; //points to first byte of src searched string
 srcstrsearchend: pbyte; //points to a byte after src searched string
 error: integer; //error code (if <> ICE_NOERROR then srcend points to current byte in srcbuf)
 optimize: integer; //optimized search range (currently filled with constanta)
 bitacu, //bits accumulator and
 bitleft: integer; //its free bits minus 1
 bytecnt: integer; //copied bytes counter (i.e. just length of non-packed sequence in dstbuf)
 b1: integer; //first byte of sample string/same byte sequence
 b2: integer; //second byte of sample string
 samebyteslength: integer; //length of found same bytes sequence
 stringlength: integer; //the best string according to algorithm
 acceptedlength: integer;
 //copy of either stringlength or samebyteslength depending of algorithm choosing
 acceptedoffset: integer;
 //either 0 for same bytes sequence or offset to string depending of algorithm choosing
 slen, //string length and
 sofs: integer; //offset for current search iteration

// Store L in destination buffer
 procedure longword_store(L: integer);
 begin
   //no need to check destination size (already checked at entry of ice_packer)
   PLongWord(dstcur)^ := SwapEndian(L);
   Inc(PLongWord(dstcur));
 end;

 // Store bit field in bitacu or/and at destcur
 // B - bits, N - number of bits in B minus 1
 procedure put_bits(B, N: integer);
 begin
   repeat
     bitacu := bitacu or ((B and 1) shl 8);
     B := B shr 1;
     bitacu := bitacu shr 1;
     Dec(bitleft);
     if bitleft < 0 then
      begin
       if dstcur >= dstend then
        begin
         error := ICE_NOROOM;
         srcend := srccur;
         Exit;
        end;
       dstcur^ := bitacu;
       Inc(dstcur);
       bitacu := 0;
       bitleft := 7;
      end;
     Dec(N);
   until N < 0;
 end;

 procedure make_offset_2;
 var
   B, N: integer;
 begin
   B := acceptedoffset;
   if B > $3f then
    begin
     B -= $40;
     N := 9;
     B := B or (1 shl N);
    end
   else
     N := 6;
   put_bits(B, N);
 end;

 procedure make_offset_more;
 const
   ta: array[0..2] of smallint = ($0000, $0020, $0120);
   tb: array[0..2] of smallint = ($0606, $0908, $0C0D);
 var
   i, ofsi, ofs: integer;
 begin
   for i := 2 downto 0 do
    begin
     ofsi := ta[i];
     if acceptedoffset >= ofsi then
       Break;
    end;
   ofs := acceptedoffset - ofsi;
   i := tb[i];
   put_bits((-1 shl (i shr 8)) or ofs, i and $f);
 end;

 procedure make_stringlength;
 const
   ta: array[0..4] of integer = ($2, $3, $4, $6, $a);
   tb: array[0..4] of integer = ($1, $1, $2, $3, $a);
 var
   i, leni, len: integer;
 begin
   for i := 4 downto 0 do
    begin
     leni := ta[i];
     if leni <= acceptedlength then
       break;
    end;
   len := acceptedlength - leni;
   leni := tb[i];
   put_bits((-1 shl leni) or len, leni + i - 1);
 end;

 procedure make_normal_bytes;
 const
   t1a: array[0..6] of integer = (0, 1, 2, 5, 8, 15, 270);
   t1b: array[0..6, 0..1] of integer = (
     ($01, $01), ($01, $02), ($02, $04), ($02, $06),
     ($03, $09), ($08, $11), ($0f, $20)
     );
 var
   i, cnti: integer;
 begin
   if bytecnt > ICE_MAXCOPYBYTES then
    begin
     error := ICE_UNPACKABLETOOLONG;
     srcend := srccur;
     Exit;
    end;

   for i := 6 downto 0 do
    begin
     cnti := t1a[i];
     if cnti <= bytecnt then
       break;
    end;
   put_bits((-1 shl t1b[i, 0]) or (bytecnt - cnti), t1b[i, 1] - 1);
   bytecnt := 0;
 end;

 procedure copy_byte; inline;
 begin
   if dstcur >= dstend then
    begin
     error := ICE_NOROOM;
     srcend := srccur;
     Exit;
    end;
   dstcur^ := srccur^;
   Inc(dstcur);
   Inc(srccur);
   Inc(bytecnt);
 end;

 function search_string_start: boolean;
 begin
   Result := False;
   while not Result and //not found
     (srccursearch < srcmaxsearch - 1) do //at least two bytes need
    begin
     Result := (srccursearch^ = b1) and (srccursearch[1] = b2);
     Inc(srccursearch);
    end;
 end;

 procedure drop_one_byte; inline;
 begin
   copy_byte;
 end;

 procedure drop_length;
 begin
   make_stringlength;
   bytecnt := 0;
   srccur += acceptedlength;
 end;

 procedure drop_two_bytes;
 begin
   if acceptedoffset > ICE_MAXOFFSET_2 then
     drop_one_byte
   else
    begin
     make_normal_bytes;
     make_offset_2;
     drop_length;
    end;
 end;

 procedure drop_more_bytes;
 begin
   make_normal_bytes;
   make_offset_more;
   drop_length;
 end;

 procedure drop_same;
 begin
   acceptedlength := samebyteslength;
   acceptedoffset := 0;
   if samebyteslength = 2 then
     drop_two_bytes
   else
     drop_more_bytes;
 end;

 {%H-}begin
 if dstsz <= 12 then
  begin
   error := ICE_NOROOM;
   srcend := srcbuf;
  end
 else
  begin
   srcend := srcbuf + srcsz;
   dstend := dstbuf + dstsz;
   srccur := srcbuf;
   dstcur := dstbuf;

   error := ICE_NOERROR;
   optimize := ICE_OPTIMIZE;

   // Store header
   longword_store(ICE_HEADER);   (* Store magic id 'ICE!'         *)
   dstcur += 4;                  (* Leave space for packed length *)
   longword_store(srcsz);        (* Store unpacked length         *)

   bitacu := 0;
   bitleft := 7;

   // Store one bit for picture flag (see comment about "not tested" in Ice.dpr depacker)
   put_bits(0, 0);

   acceptedlength := 0;
   acceptedoffset := 0;
   bytecnt := 0;

   while srcend - srccur >= 3 do //at least 3 bytes
    begin

     // 1. Sequence of identical bytes are looking for pay

     srcmaxsearch := srccur + ICE_MAXLENGTH; // end of the search range
     if srcmaxsearch > srcend then
       srcmaxsearch := srcend;

     srccursearch := srccur; // beginning of the search range
     b1 := srccursearch^;
     Inc(srccursearch); // current byte

     while (srccursearch < srcmaxsearch) and (srccursearch^ = b1) do
       Inc(srccursearch);

     samebyteslength := srccursearch - srccur - 1;
     //sequence length minus 1 to drop 1 byte as sample

     if samebyteslength = ICE_MAXLENGTH then
       //no need to search string, this sequence will be packed better in any case
       drop_same
     else
      begin

       // 2. Search string with the greatest possible length and a small offset

       stringlength := 1; //if is not found, just one byte will be dropped to dstbuf

       //set optimal/available search range
       srcmaxsearch := srccur + optimize;
       if srcmaxsearch > srcend then
         srcmaxsearch := srcend;

       srccursearch := srccur + 2; //at least two bytes

       b1 := srccur^;
       b2 := srccur[1];

       while search_string_start do //search first
        begin
         //srccur points to first byte of sample string
         srcstrend := srccur + 1; //points to second byte of sample string

         srcstrsearchbegin := srccursearch - 1;
         //points to first byte of already found pair
         srcstrsearchend := srccursearch; //points to second byte of already found pair

         repeat
           Inc(srcstrend);
           Inc(srcstrsearchend);
           if (srcstrend >= srcstrsearchbegin) or //went searched string begin
             (srcstrsearchend >= srcmaxsearch) or //exceeded searched range end
             (srcstrend^ <> srcstrsearchend^) then //found difference
             Break;
         until False;

         slen := srcstrend - srccur; //found string length
         sofs := srcstrsearchend - srcstrend - slen + 1; //offset to found string

         if slen > ICE_MAXLENGTH then
          begin
           sofs += slen - ICE_MAXLENGTH;
           slen := ICE_MAXLENGTH;
          end;

         if (slen > stringlength) and //found bigger string
           ((slen <= 2) or //drop_two_bytes checks offset itself,
           //and 1 byte string no need offset at all
           //though slen can't be < 2 here (in original algorithm can)
           (sofs <= ICE_MAXOFFSET_MORE) //offset to long string is encodable
           ) then
          begin
           stringlength := slen;
           acceptedlength := stringlength;
           acceptedoffset := sofs;

           if stringlength = ICE_MAXLENGTH then
             // the biggest allowed string found, so no need to search more
             Break;
          end;
        end;

       if (samebyteslength > 1) and (samebyteslength >= stringlength) then
         drop_same
       else
        begin
         case stringlength of
           1:
             drop_one_byte;
           2:
             drop_two_bytes;
         else
           drop_more_bytes;
          end;
        end;
      end;
    end;

   //Can be just Move(srccur^,dsrcur^,bytecnt) with dstbuf room checking
   //but srcend - srccur < 3, therefore its fast loop already
   while srccur < srcend do
     copy_byte;

   make_normal_bytes; //save info bits about last copied bytes

   if dstcur >= dstend then
    begin
     error := ICE_NOROOM;
     srcend := srccur;
    end
   else
     //save remained bits
    begin
     bitacu := bitacu or (1 shl bitleft);
     dstcur^ := bitacu;
     Inc(dstcur);
    end;

   Result.ArchiveSize := dstcur - dstbuf;
   dstcur := dstbuf + 4;
   longword_store(Result.ArchiveSize);
  end;
 if error <> ICE_NOERROR then
  begin
   Result.ErrorCode := error;
   Result.ErrorPos := srcend - srcbuf;
  end;
end;

end.
