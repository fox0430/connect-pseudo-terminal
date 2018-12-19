import posix, os ,termios

proc posix_openpt(flags: cint): cint {.importc: "posix_openpt", header: """#include <stdlib.h> #include <fcntl.h>""".}
proc grantpt(fildes: cint): cint {.importc: "grantpt", header: "<stdlib.h>".}
proc unlockpt(fildes: cint): cint {.importc: "unlockpt", header: "<stdlib.h>".}
proc ptsname(fildes: cint): cstring {.importc: "ptsname", header: "<stdlib.h>".}


proc ptyMasterOpen(slaveName: var string, snLen: int): cint =

  # Open pty master 
  let masterFd =  posix_openpt(posix.O_RDWR or posix.O_NOCTTY)
  if masterFd == -1:
    return -1

  # Grant access to slave pty
  if grantpt(masterFd) == -1:
    discard posix.close(masterFd)
    return -1
  # Unlock slave pty
  if unlockpt(masterFd) == -1:
    discard posix.close(masterFd)
    return -1

  # Get slave pty name
  let ptsName = ptsname(masterFd)
  if ptsName == nil:
    discard posix.close(masterFd)
    return -1

  if ptsName.len < snLen:
    slaveName = $ptsName
    slaveName = slaveName[0 .. snLen]
  else:
    discard posix.close(masterFd)
    return -1

  return masterFd

proc ptyFork(masterFd: var int, slaveName: var string, snLen: int, slaveTermios: ptr Termios): Pid =
  var slname = ""
  let mfd = ptyMasterOpen(slname, snLen)
  if mfd == -1:
    discard posix.close(mfd)
    return -1

  if slaveName == "":
    if 1000 < snLen:
      slaveName = slname
    else:
      discard posix.close(mfd)
      return -1

  let childPid = fork()
  if childPid == -1:
    discard posix.close(mfd)
    return -1

  if childPid != 0:
    masterFd = mfd
    return childPid

  if setsid() == -1: quit()

  discard posix.close(mfd)
  let slaveFd = posix.open(slname, posix.O_RDWR)
  if slaveFd == -1:
    quit()

  if slaveTermios != nil:
    if tcSetAttr(slaveFd, TCSANOW, slaveTermios) == -1:
      quit()


  if dup2(slaveFd, STDIN_FILENO) != STDIN_FILENO:
    quit()
  if dup2(slaveFd, STDOUT_FILENO) != STDOUT_FILENO:
    quit()
  if dup2(slaveFd, STDERR_FILENO) != STDERR_FILENO:
    quit()

  if slaveFd > STDERR_FILENO:
    discard posix.close(slaveFd)

  return 0
