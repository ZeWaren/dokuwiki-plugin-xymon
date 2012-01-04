<?php
/**
 * DokuWiki Plugin xymon
 *
 * @license GPL 2 http://www.gnu.org/licenses/gpl-2.0.html
 * @author  Erwan Martin <public@fzwte.net>
 */

// must be run within Dokuwiki
if (!defined('DOKU_INC')) die();

if (!defined('DOKU_LF')) define('DOKU_LF', "\n");
if (!defined('DOKU_TAB')) define('DOKU_TAB', "\t");
if (!defined('DOKU_PLUGIN')) define('DOKU_PLUGIN',DOKU_INC.'lib/plugins/');

require_once DOKU_PLUGIN.'action.php';

class action_plugin_xymon extends DokuWiki_Action_Plugin {

    public function register(Doku_Event_Handler &$controller) {
       $controller->register_hook('DOKUWIKI_STARTED', 'BEFORE', $this, 'handle_update');
    }


    public function handle_update(Doku_Event &$event, $param) {
		global $conf;
		
        $xymon_color="clear";
		
        //find the date of the update message cache file
		$update_message_cache_filename = $conf['cachedir'].'/messages.txt';
		if(!file_exists($update_message_cache_filename)) {
		    throw new Exception('Could not find update messages file: '.$update_message_cache_filename);
		}
		$update_message_cache_date = @filemtime($update_message_cache_filename);

		//find the date of the xymon cache file
		$xymon_status_cache_file = $conf['datadir']."/xymon/xymonstatus.txt";
		if(file_exists($xymon_status_cache_file)) {
            $xymon_status_cache_file_date = @filemtime($xymon_status_cache_file);
		}
		else {
			$xymon_status_cache_file_date = 0;
		}

		//if the update message cache file is newer, update the xymon status page
		if($update_message_cache_date > $xymon_status_cache_file_date) {
            $data = io_readFile($update_message_cache_filename);
		    $msgs = explode("\n%\n",$data);
		    foreach($msgs as $msg){
		        if($msg) {
                    if (preg_match('/security/i', $msg)) {
						$xymon_color = 'red';
						break;
					}
					if(!preg_match('/^New release candidate/i', $msg)) {
						$xymon_color = 'yellow';
					}
				}
		    }
			$xymon_color = $xymon_color == 'clear' ? 'green' : $xymon_color;

			if (!file_exists($conf['datadir'].'/xymon/')) {
				@mkdir($conf['datadir'].'/xymon/');
			}
			$fp = !file_exists($xymon_status_cache_file) || is_writable($xymon_status_cache_file) ? fopen($xymon_status_cache_file, "w") : 0;
			if ($fp)	{
				fwrite($fp, "xymon_color: ".$xymon_color."\n\n");
				fwrite($fp, $data);
				fclose($fp);
			}
			else {
				msg("Xymon plugin: could not create file ".$xymon_status_cache_file, -1);
			}
		}
	}

}
