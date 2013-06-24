#by tom, for tom, nothing to see here, walk away.

#version 2.1: modified logic, separated die() and log_parsing_error(), tests ok
#version 2.0: host status check added, now testing
#version 1.1: iface status removed, cpu and mem adjusted, now testing  
#version 1.0: ok, it does work, but logfile format changed, partial in rewrite in 1.1
#version 0.1: functionality ok, proceed with production data testing

import re
import os
import sys
import fnmatch
import logging as l

#######GLOBAL VARS !!######
logger=None
errorLog=None
cputhreshold=60
memthreshold=60
debug=True
#prefix="/fwcheck"
prefix="."
###########################

def usage_and_exit():
    print "die\n"
    sys.exit(-1)

def setup_errorlog():
    global errorLog
    global debug
    global prefix
    errorLog = l.getLogger("errorlog")
    if debug:
        errorLog.setLevel(l.INFO)
    else:
        errorLog.setLevel(l.ERROR)

    fh=l.FileHandler("%s/ITM-fwlog-check-status-errorlog.log" % prefix)
    if debug:
        fh.setLevel(l.INFO)
    else:
        fh.setLevel(l.ERROR)

    fmt=l.Formatter('%(asctime)s : %(levelname)s : %(message)s')
    fh.setFormatter(fmt)

    errorLog.addHandler(fh)
    return

def log_parsing_error(msg):
    global errorLog
    #if errorLog == None: setup_errorlog()
    
    errorLog.critical(msg)
    
    msg += '\n'
    return

#like parsing_error, but also exit
def die(msg):
    global errorLog
    #if errorLog == None: setup_errorlog()
    
    errorLog.critical(msg)
    
    msg += '\n'

    sys.exit(msg)

def log_error(fwname, error, reason):
    #line: <timestamp : fwname : error-what : reason >
    
    global logger
    logger.log(l.ERROR, "%s : %s : %s", fwname, error, reason)
    return

def setup_logger():
    global logger 
    global prefix
    logger = l.getLogger("fwlog")
    logger.setLevel(l.ERROR)
    
    fh=l.FileHandler('%s/fwlog-check.log' % prefix)
    fh.setLevel(l.ERROR)

    fmt=l.Formatter('%(asctime)s : %(message)s')
    fh.setFormatter(fmt)

    logger.addHandler(fh)
    return

def check_cpu_status(fwname, logcontent):
    global debug
    global cputhreshold
    #2.3 - extract line - cpu
    #CPU utilization for 5 seconds = 27%; 1 minute: 29%; 5 minutes: 29% 
    line=re.findall('CPU utilization for 5 seconds =\s+\d+%; 1 minute:\s+(\d+)%; 5 minutes:\s+\d+%.*', logcontent)
    if len(line) > 1: 
        log_parsing_error("%s : Parse Error, cpu line count >1, not correct" % fwname)
        return
    if len(line) < 1: 
        log_parsing_error("%s : Parse Error, cpu load data not found" % fwname)
        return

    #2.4 - threshold check - cpu
    if int(line[0]) > cputhreshold: log_error(fwname, "CPU ALERT", "%s%% in use" % line[0] )
    return

def check_mem_status(fwname, logcontent):
    global debug
    global memthreshold
    #2.1 - extract relevant lines - mem
    #'^Used memory:\s+\d+ bytes \( ?(\d+)%\)$'
    line=re.findall('Used memory:\s+\d+ bytes \( ?(\d+)%\)', logcontent, flags=re.M)
    if len(line) > 1: 
        log_parsing_error("%s : Parse Error, memory line count >1, not correct" % fwname)
        return
    if len(line) < 1: 
        log_parsing_error("%s : Parse Error, memory usage data not found" % fwname)
        return

    #2.2 - threshold check
    if int(line[0]) > memthreshold: log_error(fwname, "MEMORY ALERT", "%s%% in use" % line[0] )
    return

def check_fw_status(fwname, logcontent):
    global debug
    line=re.findall('This host: (\w+) - (\w+)',logcontent)
    if len(line) > 1: 
        log_parsing_error("%s : Parse Error, host status line count >1, not correct" % fwname)
        return
    if len(line) < 1 or len(line[0]) < 2: 
        log_parsing_error("%s : Parse Error, host status data not found or incorrect" % fwname)
        return

    host=line[0][0]
    status=line[0][1]
    if host != "Primary" and host != "Secondary": 
        log_parsing_error("%s : Parse Error, incorrect data" % fwname)
        return

    #3.1-check
    if host == "Primary" and status != "Active": log_error(fwname, "STATUS ALERT", "Primary host not in Active status")
    if host == "Secondary" and status != "Standby": log_error(fwname, "STATUS ALERT", "Secondary host not in Standby status")
    return

def main():
    global debug
    global errorLog
    global prefix
    #0.1-setup logging facility
    setup_logger()

    #0.2 - setup error log
    setup_errorlog()

    #0.3-for all log files, only if named fwcheck_*
    logpath="%s/" % prefix #production
    #logpath="./fwcheck/" #testing
    logfiles=[]
    try:
        for file in os.listdir(logpath):
            if fnmatch.fnmatch(file, 'check_fw-*'):
                logfiles.append(file)
        if debug: 
            msg = "log files found: %s" % ", ".join(logfiles)
            sys.stderr.write(msg+'\n')
            errorLog.info(msg)

        if len(logfiles)== 0 : raise OSError
    except OSError:
        die("logpath %s not found or no logs inside" % logpath)
        

    for logfile in logfiles:
        fwname = re.findall('check_fw-(.*)',logfile)[0]
        if fwname == None: die("Init Error, log files names not correct")
        if debug: 
            print fwname + '\n'
            #XXX riga orribile: vecchi firewall producono log  "non compliant" alla normale formattazione
            #per ora li saltiamo, SOLO in debug mode, in produzione mi aspetto non siano piu' presenti tali log
            #e in presenza di file non compliant lo script deve giustamente fallire
            if fwname == 'bruxelles' or fwname == 'contarini' or fwname == 'rovigo' or fwname == 'intranet': 
                msg="skipping fw %s" % fwname
                errorLog.info(msg)
                sys.stderr.write(msg+'\n')
                continue

        f=open(logpath+logfile)
        logcontent=f.read()
        f.close()

        #1-check interfaces
        #not needed anymore, removed

        #2-check cpu and memory
        check_cpu_status(fwname, logcontent)

        check_mem_status(fwname, logcontent)

        #3-Host status check:
        check_fw_status(fwname, logcontent)

    return


if __name__ == "__main__":
  #Run as main program
    main()
