#!/bin/bash

#define the directory where box86 will be installed
DIR="$HOME/Documents/box86-auto-build"
#define the directory where the deb will be moved to
DEBDIR="$HOME/Documents/box86-auto-build/debs"
#define the email variable
#if [[ ! -f "$DIR/email" ]]; then
#	echo -e "$(tput setaf 6)$(tput bold)enter your email:$(tput sgr 0)"
#	read EMAIL
#	while true; do
#	echo "Do you want to save this email? (y/n)"
#	read answer
#	if [[ "$answer" == "y" ]] || [[ "$answer" == "Y" ]] || [[ "$answer" == "yes" ]] || [[ "$answer" == "YES" ]]; then
#		echo "ok, saving this email."
#		echo "$EMAIL" > $DIR/email
#		touch $DIR/box86-2deb-weekly_log.log
#		echo "[ $(date) ] saved email ($EMAIL)." >> $DIR/box86-2deb-weekly_log.log
#		break
#	elif [[ "$answer" == "n" ]] || [[ "$answer" == "N" ]] || [[ "$answer" == "no" ]] || [[ "$answer" == "NO" ]]; then
#		echo "ok, won't save this email."
#		break
#	else
#		echo -e "$(tput setaf 3)invalid option '$answer'$(tput sgr 0)"
#	fi
#
#	done
#else
#	EMAIL="$(cat $DIR/email)"
#fi
#define the gpg key password variable
#if [[ ! -f "$DIR/gpgpass" ]]; then
#	echo -e "$(tput setaf 6)$(tput bold)enter your gpg key password:$(tput sgr 0)"
#	read GPGPASS
#	while true; do
#	echo "Do you want to save this gpg key password? (y/n)"
#	read answer
#	if [[ "$answer" == "y" ]] || [[ "$answer" == "Y" ]] || [[ "$answer" == "yes" ]] || [[ "$answer" == "YES" ]]; then
#		echo "ok, saving this password."
#		echo "$GPGPASS" > $DIR/gpgpass
#		touch $DIR/box86-2deb-weekly_log.log
#		echo "[ $(date) ] saved gpg key password." >> $DIR/box86-2deb-weekly_log.log
#		break
#	elif [[ "$answer" == "n" ]] || [[ "$answer" == "N" ]] || [[ "$answer" == "no" ]] || [[ "$answer" == "NO" ]]; then
#		echo "ok, won't save this password."
#		break
#	else
#		echo -e "$(tput setaf 3)invalid option '$answer'$(tput sgr 0)"
#	fi
#
#	done
#else
#	GPGPASS="$(cat $DIR/gpgpass)"
#fi

function error() {
	echo -e "\e[91m$1\e[39m"
    echo "[ $(date) ] | ERROR | $1" >> $DIR/box86-2deb-weekly_log.log
	exit 1
 	break
}

function warning() {
	echo -e "$(tput setaf 3)$(tput bold)$1$(tput sgr 0)"
    echo "[ $(date) ] | WARNING | $1" >> $DIR/box86-2deb-weekly_log.log
}

#compile box86 function
function compile-box86(){
	echo "compiling box86..."
	cd ~/Documents/box86-auto-build || error "Failed to change directory! (line 71)"
	git clone https://github.com/ptitSeb/box86 || error "Failed to git clone box86 repo! (line 72)"
	cd box86 || error "Failed to change directory! (line 73)"
	commit="$(bash -c 'git rev-parse HEAD | cut -c 1-8')"
	committed="$(cat /home/pi/Documents/box86-auto-build/commit.txt)"
	if [ "$commit" == "$committed" ]; then
		echo "ERROR! box86 is already up to date! deleting folder and exiting"
   		cd ~/ && rm -rf /home/pi/Documents/box86-auto-build/box86
		exit
	fi
	#echo $commit > /home/pi/Documents/box86-auto-build/commit.txt
	mkdir build; cd build; cmake .. -DRPI4=1 -DCMAKE_BUILD_TYPE=RelWithDebInfo || error "Failed to run cmake! (line 74)"
	make -j4 || error "Failed to run make! (line 75)"
	#get current directory path
	BUILDDIR="$(pwd)" || error "Failed to set BUILDDIR variable! (line 77)"
}

#get just compiled (not installed) box86 version
#USAGE: get-box86-version <option>
#OPTIONS: ver = box86 version (example: 0.2.1); commit: box86 commit (example: db176ad3).
function get-box86-version() {
	if [[ $1 == "ver" ]]; then
		BOX86VER="$(./box86 -v | cut -c21-25)"
	elif [[ $1 == "commit" ]]; then
		BOX86COMMIT="$(./box86 -v | cut -c27-34)"
	fi
}

#package box86 into a deb using checkinstall function
function package-box86() {
	cd $BUILDDIR || error "Failed to change directory to $BUILDDIR! (line 93)"
	#create the doc-pak directory and copy to it the readme, usage, changelog and license.
	#this will go in /usr/doc/box86 when the deb is installed.
	mkdir doc-pak || error "Failed to create doc-pak! (line 96)"
	cp $DIR/box86/docs/README.md $BUILDDIR/doc-pak || error "Failed to copy README.md to doc-pak! (line 97)"
	cp $DIR/box86/docs/CHANGELOG.md $BUILDDIR/doc-pak || error "Failed to copy CHANGELOG.md to doc-pak! (line 98)"
	cp $DIR/box86/docs/USAGE.md $BUILDDIR/doc-pak || error "Failed to copy USAGE.md to doc-pak! (line 99)"
	cp $DIR/box86/LICENSE $BUILDDIR/doc-pak || error "Failed to copy LICENSE to doc-pak! (line 100)"
	cp $DIR/box86/docs/X86WINE.md $BUILDDIR/doc-pak || error "Failed to copy X86WINE.md to doc-pak! (line 101)"
	#create description-pak.
	#checkinstall will use this for the deb's control file description and summary entries.
	echo "Linux Userspace x86 Emulator with a twist.

	Box86 lets you run x86 Linux programs (such as games)
	on non-x86 Linux, like ARM 
	(host system needs to be 32bit little-endian).">description-pak || error "Failed to create description-pak! (line 108)"
	echo "#!/bin/bash
	echo 'restarting systemd-binfmt...'
	systemctl restart systemd-binfmt || true">postinstall-pak || error "Failed to create postinstall-pak! (line 111)"
	
	#get the just compiled box86 version using the get-box86-version function.
	get-box86-version ver  || error "Failed to get box86 version! (line 114)"
	get-box86-version commit || error "Failed to get box86 commit (sha1)! (line 115)"
	DEBVER="$(echo "$BOX86VER+$(date +"%F" | sed 's/-//g').$BOX86COMMIT")" || error "Failed to generate box86 version for the deb! (line 116)"
	#use checkinstall to package box86 into a deb.
	#all the options are so checkinstall doesn't ask any questions but still has the data it needs.
	sudo checkinstall -y -D --pkgversion="$DEBVER" --provides="box86" --conflicts="qemu-user-static" --pkgname="box86" --install="no" make install || error "Failed to run checkinstall! (line 119)"
}

function clean-up() {
	#current date in YY/MM/DD format
	NOWDAY="$(printf '%(%Y-%m-%d)T\n' -1)" || error 'Failed to get current date! (line 124)'
	#make a folder with the name of the current date (YY/MM/DD format)
	mkdir -p $DEBDIR/$NOWDAY || error "Failed to create folder for deb! (line 126)"
	#make a file with the current sha1 (commit) of the box86 version just compiled.
	echo $BOX86COMMIT > $DEBDIR/$NOWDAY/sha1.txt || error "Failed to write box86 commit (sha1) to sha1.txt! (line 128)"
	#move the deb to the directory for the debs. if it fails, try again as root
	mv box86*.deb $DEBDIR/$NOWDAY || sudo mv box86*.deb $DEBDIR/$NOWDAY || error "Failed to move deb! (line 130)"
	#remove the home directory from the deb
	cd $DEBDIR/$NOWDAY || error "Failed to change directory to $DEBDIR/$NOWDAY! (line 132)"
	FILE="$(basename *.deb)" || error "Failed to get deb filename! (line 133)"
	FILEDIR="$(echo $FILE | cut -c1-28)" || error "Failed to generate name for directory for the deb! (line 134)"
	dpkg-deb -R $FILE $FILEDIR || error "Failed to extract the deb! (line 135)"
	rm -r $FILEDIR/home || warning "Failed to remove home folder from deb! (line 136)"
	#cd $FILEDIR/usr || error "Failed to cd into '$FILEDIR/usr/'! (line 137)"
	#mv local/bin/ . || error "Failed to move 'bin' to '.'! (line 138)"
	#rm -r local/ || error "Failed to remove 'local'! (line 13)"
	#cd ../../ || error "Failed to go 2 directories up! (line 140)"
	rm -f $FILE || error "Failed to remove old deb! (line 141)"
	dpkg-deb -b $FILEDIR $FILE || error "Failed to repack the deb! (line 142)"
	rm -r $FILEDIR || error "Failed to remove temporary deb directory! (line 143)"
	cd $DEBDIR || error "Failed to change directory to $DEBDIR! (line 144)"
	#compress the folder with the deb and sha1.txt into a tar.xz archive
	tar -cJf $NOWDAY.tar.xz $NOWDAY/ || error "Failed to compress today's build into a tar.xz archive! (line 146)"
	#remove the box86 folder
	cd $DIR || error "Failed to change directory to $DIR! (line 148)"
	sudo rm -rf box86 || error "Failed to remove box86 folder! (line 149)"
}

function upload-deb() {
    EMAIL="$(cat /home/pi/Documents/box86-auto-build/email)"
	GPGPASS="$(cat /home/pi/Documents/box86-auto-build/gpgpass)"
	#copy the new deb and tar.xz
	cp $DEBDIR/$NOWDAY/box86*.deb $HOME/Documents/box86-debs/debian/ || error "Failed to copy new deb! (line 154)"
	cp $DEBDIR/$NOWDAY.tar.xz $HOME/Documents/box86-debs/debian/source/$NOWDAY.tar.xz || error "Failed to copy new tar.xz archive! (line 155)"
	#remove apt files
	rm $HOME/Documents/box86-debs/debian/Packages || warning "Failed to remove old 'Packages' file! (line 157)"
	rm $HOME/Documents/box86-debs/debian/Packages.gz || warning "Failed to remove old 'Packages.gz' archive! (line 158)"
	rm $HOME/Documents/box86-debs/debian/Release || warning "Failed to remove old 'Release' file! (line 159)"
	rm $HOME/Documents/box86-debs/debian/Release.gpg || warning "Failed to remove old 'Release.gpg' file! (line 15960)"
	rm $HOME/Documents/box86-debs/debian/InRelease || warning "Failed to remove old 'InRelease' file! (line 161)"
	#create new apt files
	cd $HOME/Documents/box86-debs/debian/ || error "Failed to change directory! (line 163)"
	dpkg-scanpackages --multiversion . > Packages
	gzip -k -f Packages
	apt-ftparchive release . > Release
	gpg --default-key "${EMAIL}" --batch --pinentry-mode="loopback" --passphrase="$GPGPASS" -abs -o - Release > Release.gpg
	gpg --default-key "${EMAIL}" --batch --pinentry-mode="loopback" --passphrase="$GPGPASS" --clearsign -o - Release > InRelease
	cd .. || error "Failed to move one directory up! (line 180)"
	git pull origin master || error "Failed to run 'git pull'! (line 182)"
	git add . || error "Failed to run git add! (line 183)"
    git commit -m "Updated Box86 v$BOX86VER to $BOX86COMMIT"
	git push origin master || error "Failed to run 'git push'! (line 186)"
	cd $DIR || error "Failed to change directory to $DIR! (line 188)"
}

# Run everything #
echo "compile time!"
compile-box86 || error "Failed to run compile-box86 function! (line 204)"
package-box86 || error "Failed to run package-box86 function! (line 205)"
clean-up || error "Failed to run clean-up function! (line 206)"
echo $commit > /home/pi/Documents/box86-auto-build/commit.txt
#write to the log file that build and packaging are complete
touch box86-2deb-weekly_log.log
TIME="$(date)"
echo "
=============================
$TIME
=============================" >> box86-2deb-weekly_log.log
NOWTIME="$(date +"%T")"
echo "[$NOWTIME | $NOWDAY] build and packaging complete." >> box86-2deb-weekly_log.log
upload-deb || error "Failed to upload deb! (line 217)"
#write to log that uploading is complete
NOWTIME="$(date +"%T")"
echo "[$NOWTIME | $NOWDAY] uploading complete." >> box86-2deb-weekly_log.log
