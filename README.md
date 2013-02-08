BitTorrent-Ruby
===============
Deonna, Ankeet
requires ruby gem bencode
    > gem install bencode



Current design plan:
 1 select a bunch of peers, create new threads(?) for each. remember they might time out within 2 minutes, keepalive if necessary
 2 handshake and grab their bitfields as above (all of the above code after "# select a peer somehow" needs to be put into peer threads
 3 tabulate piece frequencies from these bitfields (will need some sort of locking so these threads don't run into race conditions)
 4 find peers that have rarest undownloaded pieces (starting with above peers, then going selecting more random peers?) (4 at a time?)
 5a within these peers' threads: send "interested", (figure out unchoking?), send "request", receive "piece", send "have"
 5b    verify SHA1, save piece to file
 6 update bitfield (will require locking)
 7 if own bitfield != ffffff... go back to step 4
need something for uploading - should this be in yet another set of thread/peer? send out bitfield?
 8 receive "interested", (figure out choking), receive "request", send "piece", receive "have"
probably a better way to deal with stuff asynchronously

