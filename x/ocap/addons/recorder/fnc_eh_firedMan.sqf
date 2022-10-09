/* ----------------------------------------------------------------------------
Script: FUNC(eh_firedMan)

Description:
  Tracks bullet and non-bullet projectiles. This is the code triggered when a unit firing is detected by the "FiredMan" Event Handler applied to units during <FUNC(addUnitEventHandlers)>.

Parameters:
  _firer - Unit the event handler is assigned to (the instigator) [Object]
  _weapon - Fired weapon [String]
  _muzzle - Muzzle that was used [String]
  _mode - Current mode of the fired weapon [String]
  _ammo - Ammo used [String]
  _magazine - Magazine name which was used [String]
  _projectile - Object of the projectile that was shot out [Object]
  _vehicle - if weapon is vehicle weapon, otherwise objNull [Object]

Returns:
  Nothing

Examples:
  --- Code
  ---

Public:
  No

Author:
  IndigoFox, Dell
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!SHOULDSAVEEVENTS) exitWith {};

params ["_firer", "_weapon", "_muzzle", "_mode", "_ammo", "_magazine", "_projectile", "_vehicle"];

private _initialProjPos = getPos _projectile;
if (getPos _firer distance _initialProjPos > 50 || vehicle _firer isKindOf "Air") then {
  // if projectile in unscheduled environment is > 50m from FiredMan then likely remote controlled
  // we should find the actual firing entity
  private _nearest = [_initialProjPos, allUnits select {!isPlayer _x}, 75] call CBA_fnc_getNearest;
  if (count _nearest > 0) then {
    _firer = _nearest#0;
  };
};

// missionNamespace getVariable ["bis_fnc_moduleRemoteControl_unit", _firer];
// _unit getVariable ["BIS_fnc_moduleRemoteControl_owner", objNull];

// not sent in ACE Throwing events
if (isNil "_vehicle") then {_vehicle = objNull};
if (!isNull _vehicle) then {
  _projectile setShotParents [_vehicle, _firer];
} else {
  _projectile setShotParents [_firer, _firer];
};

private _frame = GVAR(captureFrameNo);

private _firerId = (_firer getVariable [QGVARMAIN(id), -1]);
if (_firerId == -1) exitWith {};

// set the firer's lastFired var as this weapon, so subsequent kills are logged accurately
([_weapon, _muzzle, _magazine, _ammo] call FUNC(getWeaponDisplayData)) params ["_muzzleDisp", "_magDisp"];

private _wepString = "";
if (_muzzleDisp find _magDisp == -1 && _magDisp isNotEqualTo "") then {
  _wepString = format["%1 [%2]", _muzzleDisp, _magDisp];
} else {
  _wepString = _muzzleDisp;
};
if (!isNull _vehicle) then {
  _wepString = format["%1 [%2]", (configOf _vehicle) call BIS_fnc_displayName, _wepString];
};
_firer setVariable [QGVARMAIN(lastFired), _wepString];
(vehicle _firer) setVariable [QGVARMAIN(lastFired), _wepString];

_ammoSimType = getText(configFile >> "CfgAmmo" >> _ammo >> "simulation");

// Save marker data to projectile namespace for EH later
_projectile setVariable [QGVAR(firer), _firer];
_projectile setVariable [QGVAR(firerId), _firerId];

// Track hit events for all projectile types
_projectile addEventHandler ["HitPart", {
  params ["_projectile", "_hitEntity", "_projectileOwner", "_pos", "_velocity", "_normal", "_component", "_radius" ,"_surfaceType"];
  LOG(ARR2("HitPart", _hitEntity));
  [_hitEntity, _projectileOwner] call FUNC(eh_projectileHit);
}];

_projectile addEventHandler ["HitExplosion", {
  params ["_projectile", "_hitEntity", "_projectileOwner", "_hitThings"];
  LOG(ARR2("HitExplosion", _hitEntity));
  [_hitEntity, _projectileOwner] call FUNC(eh_projectileHit);
}];

// _ammoSimType
// "ShotGrenade" // M67
// "ShotRocket" // S-8
// "ShotMissile" // R-27
// "ShotShell" // VOG-17M, HE40mm
// "ShotMine" // Satchel charge
// "ShotIlluminating" // 40mm_green Flare
// "ShotSmokeX"; // M18 Smoke
// "ShotCM" // Plane flares
// "ShotSubmunition" // Hind minigun, cluster artillery


if (_ammoSimType isEqualTo "shotBullet") exitWith {
  // Bullet projectiles
  _projectile addEventHandler ["Deleted", {
    params ["_projectile"];
    _firer = _projectile getVariable [QGVAR(firer), objNull];
    _firerId = _projectile getVariable [QGVAR(firerId), -1];
    _projectilePos = getPosASL _projectile;

    [":FIRED:", [
      _firerId,
      GVAR(captureFrameNo),
      _projectilePos
    ]] call EFUNC(extension,sendData);

    if (GVARMAIN(isDebug)) then {
      OCAPEXTLOG(ARR4("FIRED EVENT: BULLET", GVAR(captureFrameNo), _firerId, str _projectilePos));

      // add to clients' map draw array
      private _debugArr = [getPosASL _firer, _projectilePos, [side group _firer] call BIS_fnc_sideColor, cba_missionTime];
      [QGVAR(addDebugBullet), _debugArr] call CBA_fnc_globalEvent;
    };
  }];
};


// ALL OTHER PROJECTILES

// Get data for marker
([_weapon, _muzzle, _ammo, _magazine, _projectile, _vehicle, _ammoSimType] call FUNC(getAmmoMarkerData)) params ["_markTextLocal","_markName","_markColor","_markerType"];
private _magIcon = getText(configFile >> "CfgMagazines" >> _magazine >> "picture");
_projectile setVariable [QGVAR(markName), _markName];

// MAKE MARKER FOR PLAYBACK
_firerPos = getPosASL _firer;
[QGVARMAIN(handleMarker), ["CREATED", _markName, _firer, _firerPos, _markerType, "ICON", [1,1], getDirVisual _firer, "Solid", _markColor, 1, _markTextLocal, true]] call CBA_fnc_localEvent;



// Move marker, then delete marker, when projectile is deleted
_projectile addEventHandler ["Deleted", {
  params ["_projectile"];
  _markName = _projectile getVariable QGVAR(markName);
  _firer = _projectile getVariable QGVAR(firer);
  [QGVARMAIN(handleMarker), ["UPDATED", _markName, _firer, getPosASL _projectile, "", "", "", getDir _projectile, "", "", 1]] call CBA_fnc_localEvent;
  [{
    [QGVARMAIN(handleMarker), ["DELETED", _this]] call CBA_fnc_localEvent;
  }, _markName, GVAR(frameCaptureDelay)] call CBA_fnc_waitAndExecute;
}];

// Add to debug
if (GVARMAIN(isDebug)) then {
  // add to map draw array
  private _debugArr = [_projectile, _magIcon, format["%1 %2 - %3", str side group _firer, name _firer, _markTextLocal], [side group _firer] call BIS_fnc_sideColor];
  [QGVAR(addDebugMagIcon), _debugArr] call CBA_fnc_globalEvent;
};


switch (true) do {
  case (_ammoSimType in ["shotGrenade", "shotIlluminating", "shotMine", "shotSmokeX", "shotCM"]): {
    GVAR(liveGrenades) pushBack [_projectile, _wepString, _firer, getPosASL _projectile, _markName, _markTextLocal, _ammoSimType];
  };

  // case (_ammoSimType in ["shotMissile", "shotRocket", "shotShell", "shotSubmunitions"]): {
  default {
    GVAR(liveMissiles) pushBack [_projectile, _wepString, _firer, getPosASL _projectile, _markName, _markTextLocal];

    if (_ammoSimType isEqualTo "shotSubmunitions") then {

      _projectile setVariable [QGVAR(markerData), ([_weapon, _muzzle, _ammo, _magazine, _projectile, _vehicle, _ammoSimType] call FUNC(getAmmoMarkerData))];
      _projectile setVariable [QGVAR(EHData), [_this, _subTypes, _magazine, _wepString, _firer, _firerId, _firerPos, _frame, _ammoSimType, _subTypesAmmoSimType]];

      // for every submunition split process here
      _projectile addEventHandler ["SubmunitionCreated", {
        params ["_projectile", "_submunitionProjectile", "_pos", "_velocity"];
        (_projectile getVariable [QGVAR(markerData), []]) params ["_markTextLocal", "_markName", "_markColor", "_markerType"];
        (_projectile getVariable [QGVAR(EHData), []]) params ["_EHData", "_subTypes", "_magazine", "_wepString", "_firer", "_firerId", "_firerPos", "_frame", "_ammoSimType", "_subTypesAmmoSimType"];

        // Save marker data to projectile namespace for EH later
        _submunitionProjectile setVariable [QGVAR(firer), _firer];
        _submunitionProjectile setVariable [QGVAR(firerId), _firerId];
        _submunitionProjectile setVariable [QGVAR(markName), _markName];

        private _magIcon = getText(configFile >> "CfgMagazines" >> _magazine >> "picture");

        // then get data of submunition to determine how to track it
        private _ammoSimType = getText(configFile >> "CfgAmmo" >> (typeOf _submunitionProjectile) >> "simulation");


        // Track hit events for all projectile types
        _submunitionProjectile addEventHandler ["HitPart", {
          params ["_projectile", "_hitEntity", "_projectileOwner", "_pos", "_velocity", "_normal", "_component", "_radius" ,"_surfaceType"];
          [_hitEntity, _projectileOwner] call FUNC(eh_projectileHit);
        }];

        _submunitionProjectile addEventHandler ["HitExplosion", {
          params ["_projectile", "_hitEntity", "_projectileOwner", "_hitThings"];
          [_hitEntity, _projectileOwner] call FUNC(eh_projectileHit);
        }];

        if (_ammoSimType isEqualTo "shotBullet") exitWith {
          // Bullet projectiles
          _submunitionProjectile addEventHandler ["Deleted", {
            params ["_projectile"];
            _firer = _projectile getVariable [QGVAR(firer), objNull];
            _firerId = _projectile getVariable [QGVAR(firerId), -1];
            _projectilePos = getPosASL _projectile;

            [":FIRED:", [
              _firerId,
              GVAR(captureFrameNo),
              _projectilePos
            ]] call EFUNC(extension,sendData);

            if (GVARMAIN(isDebug)) then {
              OCAPEXTLOG(ARR4("FIRED EVENT: BULLET", GVAR(captureFrameNo), _firerId, str _projectilePos));

              // add to clients' map draw array
              private _debugArr = [getPosASL _firer, _projectilePos, [side group _firer] call BIS_fnc_sideColor, cba_missionTime];
              [QGVAR(addDebugBullet), _debugArr] call CBA_fnc_globalEvent;
            };
          }];
        };

        // Move marker, then delete marker, when projectile is deleted
        _submunitionProjectile addEventHandler ["Deleted", {
          params ["_projectile"];
          _markName = _projectile getVariable QGVAR(markName);
          _firer = _projectile getVariable QGVAR(firer);
          [QGVARMAIN(handleMarker), ["UPDATED", _markName, _firer, getPosASL _projectile, "", "", "", getDir _projectile, "", "", 1]] call CBA_fnc_localEvent;
          [{
            [QGVARMAIN(handleMarker), ["DELETED", _this]] call CBA_fnc_localEvent;
          }, _markName, GVAR(frameCaptureDelay)] call CBA_fnc_waitAndExecute;
        }];

        // Add to debug
        if (GVARMAIN(isDebug)) then {
          // add to map draw array
          private _debugArr = [_projectile, _magIcon, format["%1 %2 - %3", str side group _firer, name _firer, _markTextLocal], [side group _firer] call BIS_fnc_sideColor];
          [QGVAR(addDebugMagIcon), _debugArr] call CBA_fnc_globalEvent;
        };



        switch (true) do {
          case (_ammoSimType in ["shotGrenade", "shotIlluminating", "shotMine", "shotSmokeX", "shotCM"]): {
            GVAR(liveGrenades) pushBack [_submunitionProjectile, _wepString, _firer, getPosASL _submunitionProjectile, _markName, _markTextLocal, _ammoSimType];
          };
          // case (_ammoSimType in ["shotMissile", "shotRocket", "shotShell", "shotSubmunitions"]): {
          default {
            GVAR(liveMissiles) pushBack [_submunitionProjectile, _wepString, _firer, getPosASL _submunitionProjectile, _markName, _markTextLocal];
          };
        };
      }];
    };
  };
};
