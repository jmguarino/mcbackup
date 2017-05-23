#!/usr/bin/perl
# minecraft_update.pl - Upgrade the Minecraft server jar.
# This relies on https://launchermeta.mojang.com/mc/game/version_manifest.json
# still being a valid url which should serve a json file with a bunch
# of Minecraft metadata, including the latest version. With this version 
# obtained from the above static URL you can build the dynamic url which
# should contain the newest Minecraft server jar.
#
# Justin Guarino <justin.guarino@sonic.com> 2017-4-14

use strict;
use warnings;

use Cwd;
use File::Compare;
use JSON;
use LWP::Simple;

my $debug = 0;

# Directory where the minecraft server jar is
my $server_dir = '/opt/minecraft/server/';

my $old_manifest = 'old_version_manifest.json';
my $new_manifest = 'new_version_manifest.json';

#Mojang manifest url
my $manifest_url = 'https://launchermeta.mojang.com/mc/game/version_manifest.json';

#Mojang server jar url, to be fully built after version number is stripped from manifest
#Format should end up looking like this:
#https://s3.amazonaws.com/Minecraft.Download/versions/$VER/minecraft_server.$VER+.jar
my $serverjar_url = 'https://s3.amazonaws.com/Minecraft.Download/versions';

chdir $server_dir || die "Error changing directories to $server_dir : $!\n";

my $http_code;

#Need a manifest to check against... This means that if the file is deleted for some
#reason it may miss an update cycle (if this creates the file when the server is 
#already out of date).
if(! -e $old_manifest)
{
	if($debug) {print "Creating old manifest as the file was missing\n";}
	$http_code = getstore($manifest_url, $old_manifest);
	if($http_code != 200)
	{
	        die "Http code $http_code when fetching the new minecraft launcher manifest; did a url change?\n";
	}
	exit;
} 

if($debug) {print "Fetching new manifest\n"};
$http_code = getstore($manifest_url, $new_manifest);

if($http_code != 200)
{
	die "Http code $http_code when fetching the new minecraft launcher manifest; did a url change?\n";
}

if($debug) {print "Comparing manifests\n"};
#If manifest file changed parse to detect server version change
if(compare($old_manifest, $new_manifest))
{
	open(my $old_man_fh, "<", "$old_manifest") || die "Couldn't open $old_manifest for reading: $!";
	my $old_man_json_text = <$old_man_fh>;
	close($old_man_fh);
	my $json = JSON->new;
	my $old_man_data = $json->decode($old_man_json_text);
	my $old_man_version = $old_man_data->{'latest'}->{'release'};	

	open(my $new_man_fh, "<", "$new_manifest") || die "Couldn't open $new_manifest for reading: $!";	
	my $new_man_json_text = <$new_man_fh>;
	close($new_man_fh);
	my $new_man_data = $json->decode($new_man_json_text);
	my $new_man_version = $new_man_data->{'latest'}->{'release'};

	if($debug) {print "Old Manifest Version: $old_man_version\n";}
	if($debug) {print "New Manifest Version: $new_man_version\n";}

	#Simple check to make sure nothing weird is in the version number
	if($old_man_version !~ /([0-9]+\.*)+/ || $new_man_version !~ /([0-9]+\.*)+/)
	{
		die "Parsed version numbers appear to be in an unexpected format.\nOld version: $old_man_version\nNew version: $new_man_version";
	}	

	if($old_man_version ne $new_man_version) 
	{
		if($debug) {print "Detected an update, downloading new jar\n";}

		my $serverjar = "minecraft_server.$new_man_version.jar";

		if($debug) {print "Server jar filename: $serverjar\n";}

		my $full_url = "$serverjar_url/$new_man_version/$serverjar";	

		if($debug) {print "Dynamic url: $full_url\n";}
		if($debug) 
		{
			#Should be $server_dir
			my $cwd = getcwd;
			print "Saving new jar to: $cwd/$serverjar\n";
		}

		$http_code = getstore($full_url, "$serverjar");

		if($http_code != 200)
		{
		        die "Http code $http_code when fetching the new minecraft server jar; did the url format change?\n(We have $full_url)\n";
		}
		
		#Update symlink 
		if($debug) {print "Updating symlink\n";}

		if(system("ln -sf /opt/minecraft/server/$serverjar /opt/minecraft/server/minecraft_server_current.jar") != 0) 
		{
			die "Error making symlink (minecraft_server_current.jar pointing to /opt/minecraft/server/$serverjar\n";
		}

		if($debug) {print "Restarting minecraft service\n";}

		#Restart minecraft server
		if(system("systemctl restart minecraft") != 0){
			die "Error systemctl restarting minecraft server\n";	
		}

		if($debug) {print "Cleaning up old server jars\n";}

		#Delete all but the 3 most recent server jars
		#NOTE: Change the directory below to match your minecraft server jar location.
		if(system("ls -t /opt/minecraft/server/minecraft_server*.jar | grep -v minecraft_server_current.jar | sed -e '1,3d' | xargs -d '\n' rm") != 0){
			die "Failed to clean up old server jars\n";
		}
	}
} elsif ($debug) {
	print "Manifest files show same version.\n";
}

rename $new_manifest, $old_manifest;
if($debug) {print "Ran ok\n";}
