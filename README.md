
## SYNOPSIS
  This is a simple collection of powercli functions which improve on the built-in powercli functions.
  Primarily intended for collecting from vCenter but most things work when connected only to an ESX host.


## DESCRIPTION
  I've slowly tuned these functions over the years for my own use. Some properties were added from much older
  versions of PowerCLI. There may be more efficient ways of obtaining some properties with more recent versions
  of PowerCLI.

  Two primary goals.
  1) Provide more and relevant information on top of existing commands.
  2) Increase performance.

## NOTES
  Version:        1.0
  Author:         Matt S.
  Creation Date:  5/16/2017
  Website:        http://mjs.one
  Github:
  VMTools table:  https://packages.vmware.com/tools/versions

## TODO
 - allow pipe into get-vmB
 - find faster methods for slower functions(get-vmbhost for example)
   get-view may be faster in some cases
