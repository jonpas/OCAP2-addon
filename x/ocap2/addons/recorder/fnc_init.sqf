/* ----------------------------------------------------------------------------
Script: ocap_fnc_init

Description:
  Automatic Start: Called from ocap_fnc_autoStart.
  Manual Start: Server execution to begin.

Parameters:
  None

Returns:
  Nothing

Examples:
  --- Code
  call ocap_fnc_init;
  ---

Public:
  No

Author:
  Dell, Zealot, IndigoFox
---------------------------------------------------------------------------- */

#include "script_component.hpp"

// bool: GVAR(recording)
GVAR(recording) = false;
// int: GVAR(captureFrameNo)
GVAR(captureFrameNo) = 0;
// bool: GVAR(shouldSave)
GVAR(shouldSave) = false;

// macro: GVARMAIN(version)SION
GVARMAIN(version) = QUOTE(VERSION_STR);
publicVariable QGVARMAIN(version);

EGVAR(extension,version) = ([":VERSION:", []] call EFUNC(extension,sendData));
publicVariable QEGVAR(extension,version);


// remoteExec diary creation commands to clients listing version numbers and waiting start state
{
  [{!isNil QGVARMAIN(version) && !isNil QEGVAR(extension,version)}, {
    player createDiarySubject ["OCAP2Info", "OCAP2 AAR", "\A3\ui_f\data\igui\cfg\simpleTasks\types\whiteboard_ca.paa"];

    ocap_fnc_copyGitHubToClipboard = {copyToClipboard "https://github.com/OCAP2/OCAP"; systemChat "OCAP2 GitHub link copied to clipboard";};
    EGVAR(diary,about) = player createDiaryRecord [
      "OCAP2Info",
      [
        "About",
        (
          "<font size='20' face='PuristaBold'><font color='#BBBBBB'>OCAP</font><font color='#44AAFF'>2</font></font><br/>" +
          "Addon version: " + GVARMAIN(version) +
          "<br/>" +
          "Extension version: " + (EGVAR(extension,version) # 0) + " (built " + (EGVAR(extension,version) # 1) + ")" +
          "<br/>" +
          "<execute expression='call ocap_fnc_copyGitHubToClipboard;'>https://github.com/OCAP2/OCAP</execute>" +
          "<br/><br/>" +
          "OCAP2 is a server-side Arma 3 recording suite that provides web-based playback of all units, vehicles, markers, and projectiles present, placed, and fired during a mission." +
          "<br/><br/>" +
          "Recording status can be found in the Status section." +
          "<br/><br/>" +
          "DISCLAIMER: This mission may be recorded and made publicly available at the discretion of the server administrators. Please be aware that your actions during this mission will be tracked and attributed to your in-game username."
        )
      ]
    ];

    EGVAR(diary,status) = player createDiaryRecord [
      "OCAP2Info",
      [
        "Status",
        "OCAP2 initialized."
      ]
    ];
  }] call CBA_fnc_waitUntilAndExecute;
} remoteExecCall ["call", 0, true];


// Support both methods of setting mission name.
GVAR(missionName) = getMissionConfigValue ["onLoadName", ""];
if (GVAR(missionName) == "") then {
    GVAR(missionName) = briefingName;
};



/*
  Conditional Start Recording
  We'll wait to see if auto-start is enabled and minPlayercount setting is met. This covers scenarios where someone changes the autostart setting during the mission as well, and excludes cases where autostart is disabled.
  On execution, we'll also check if recording has already started by other means via whether GVAR(startTime) has been declared or not.
  If recording hasn't started already, we'll initialize it here assuming the above conditions are met.
*/
[
  {((count allPlayers) >= EGVAR(settings,minPlayerCount) && EGVAR(settings,autoStart)) || !isNil QGVAR(startTime)},
  {call FUNC(startRecording)},
] call CBA_fnc_waitUntilAndExecute;