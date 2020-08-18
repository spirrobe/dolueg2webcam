#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# """
# Created on Tue Jul  3 10:09:18 2018
#
# @author: spirro00
# """
def picam_timelapse(tf='%Y%m%d%H%M',
                    vidname='current',
                    daysback=2,
                    imgdir='ENTERDIRECTORYOFIMAGESHERE',
                    workdir='ENTERWHEREYOURIMAGESWILLBESTOREDTEMPORARILY',
                    outdir='ENTERWHERETOSAVETHEVIDEO',
                    copyto='ENTERWHERETOCOPYTHEVIDEO',
                    createwebm=True,
                    cleanuplinks=True,
                    quiet=False):

    from natsort import natsorted
    import datetime
    import os
    import subprocess
    import socket
    import shutil
    import imghdr
    from ftplib import FTP

    ftp = FTP(host='ENTERYOURFTPSERVER',
              user='ENTERYOURFTPUSER',
              passwd='ENTERYOURFTPPASSWORD',
              timeout=5,
              )

    files = []
    retr = ftp.retrlines("NLST", files.append)
    now = datetime.datetime.utcnow()
    aday = datetime.timedelta(days=1)

    def shottimefilter(x, maxdays=7):

        timestamp = x[4:-4]
        timestampformat = '%Y%m%d%H%M'

        if len(timestamp) > (4+2+2+2+2):
             timestampformat += '%S'

        if 'shot' in x and datetime.datetime.strptime(timestamp, timestampformat) > now- maxdays*aday:
            return True
        else:
            return False

    files = list(filter(shottimefilter, files))

    from ftplib import error_perm
    import time
    import socket
    for filename in files:
        if os.path.exists(imgdir+filename):
            continue
        if ftp.size(filename) <= 0:
            try: 
                print('Deleting {filename}'.format(filename=filename))
                ftp.delete(filename)
            except socket.timeout:
                pass
            except error_perm:
                pass
            continue

        try:
            if not quiet:
                print('Getting', filename)
            with open(imgdir+filename, "wb") as fo:
                ftp.retrbinary("RETR " + filename, fo.write)
            time.sleep(0.1)
            ftp.delete(filename)
        except socket.timeout:
            print('FTP server timeout (',datetime.datetime.now(),')')
            time.sleep(1)
            ftp.connect()
            continue
        except error_perm:
            print('Download of', filename, 'failed (',datetime.datetime.now(),')')
        except FileNotFoundError:
            print('Download of', filename, 'failed (',datetime.datetime.now(),')')

    ftp.close()

    t0 = datetime.datetime.fromordinal(datetime.datetime.utcnow().toordinal())
    t0 -= datetime.timedelta(days=daysback)

    # basically first check whether its a valid file with correct filename
    # then only check on those whether they are newer than t0 above
    # and then finally get the name from the

    files = list(map(lambda x: x.name,
                     filter(lambda x: datetime.datetime.strptime(x.name[4:-4], tf+['','%S'][int(len(x.name[4:-4]) > 12)]) >= t0,
                            filter(lambda x: x.is_file() and 'shot' in x.name,
                                   os.scandir(imgdir)))))
    files = natsorted(files)

    if not files:
        print('No files fitting the timerange, please check your FTP/WEBCAM')
        return False

    if not quiet:
        print('Linking', len(files), 'files for timelapse')

    # the number of files we need so we have the proper dateformat
    # for the command in the first place
    maxnum = len(str(len(files)))
    count = 0

    # create a list of percentage to report at
    percs = [i*5 for i in range(1, 20)]

    for fileno, file in enumerate(files):
        try:
            if imghdr.what(imgdir+file) == 'jpeg':
               # is this a proper jpeg file?
               count += 1
            else:
                if not quiet:
                    print('Not a proper jpeg:', imgdir+file,
                          'but a', imghdr.what(imgdir+file))
                    print('The offending file will be deleted')
                os.remove(imgdir+file)
                continue
        except FileNotFoundError:
            continue

        newfile = workdir+str(count).zfill(maxnum)+'.jpg'

        if os.path.exists(newfile):
            os.remove(newfile)

        if not quiet:
            perc = int(fileno/len(files)*100)
            if perc in percs:
                print('Progress:', perc, '%')
                percs.remove(perc)

        linkcmd = 'ln ' + imgdir + file + ' ' + newfile
        try:
            subprocess.check_call(linkcmd.split(' '))
        except subprocess.CalledProcessError as err:
            if not quiet:
                print('Linking failed with:', linkcmd)
            # reduce count by one so we have
            count -= 1
            continue

    mp4file = outdir+vidname+'.mp4'
    webmfile = outdir+vidname+'.webm'

    if os.path.exists(mp4file):
        os.remove(mp4file)

    if os.path.exists(webmfile):
        os.remove(webmfile)

    mp4cmd = 'ffmpeg '

    if quiet:
        mp4cmd += '-loglevel panic '

    mp4cmd += '-hide_banner -f image2 -r 12 -start_number 1 -i '
    mp4cmd += workdir+'%'+str(maxnum)
    mp4cmd += 'd.jpg -y -r 12 -s hd1080 -vcodec libx264 -pix_fmt yuv444p '
    #mp4cmd += '-vf deshake=x=0:y=1000:w=1600:h=500 '
    mp4cmd += mp4file

    try:
        subprocess.check_call(mp4cmd.split(' '))
    except subprocess.CalledProcessError:
        return False

    if os.path.exists(mp4file):
        shutil.copy(mp4file, copyto)

    if createwebm:
        webmcmd = 'ffmpeg -loglevel panic -hide_banner -y -i '
        webmcmd += mp4file
        webmcmd += ' -crf 25 -b:v 2M -vcodec libvpx-vp9 -cpu-used 8 -acodec libvorbis -pix_fmt yuv444p '
        webmcmd += webmfile

        webmcmd = 'ffmpeg '

        if quiet:
            webmcmd += '-loglevel panic '

        webmcmd += '-hide_banner -f image2 -r 12 -start_number 1 -i '
        webmcmd += workdir+'%'+str(maxnum)
        webmcmd += 'd.jpg -y -r 12 -crf 25 -b:v 2M -vcodec libvpx -cpu-used 8 '
        webmcmd += webmfile

        try:
            subprocess.check_call(webmcmd.split(' '))
        except subprocess.CalledProcessError:
            return False

        if os.path.exists(webmfile):
            shutil.copy(webmfile, copyto)

    if cleanuplinks:
        for f in natsorted(os.listdir(workdir)):
            os.remove(workdir+f)

    return True

if __name__ == '__main__':
    result = picam_timelapse(quiet=True)
    if result:
        import datetime
        print('Successfully created both videos at',
             datetime.datetime.utcnow(),'UTC')
    else:
        print('Timelapsecreation failed at',
             datetime.datetime.utcnow(),'UTC')
