/* ----------------------------------------------------------------------------
Script: FUNC(eh_hit)

Description:
  Tracks when a unit is hit/takes damage. This is the code triggered by the "MPHit" Event Handler applied to units during <FUNC(addUnitEventHandlers)>.

Parameters:
  _unit - Object the event handler is assigned to. [Object]
  _causedBy - Object that caused the damage. Contains the unit itself in case of collisions. [Object]
  _damage - Level of damage caused by the hit. [Number]
  _instigator - Object - Person who pulled the trigger. [Object]

Returns:
  Nothing

Examples:
  --- Code
  ---

Public:
  No

Author:
  IndigoFox, Fank
---------------------------------------------------------------------------- */
#include "script_component.hpp"

params ["_unit", "_causedBy", "_damage", "_instigator"];

[_unit, _causedBy, _instigator] spawn {
  params ["_unit", "_causedBy", "_instigator"];

  if (isNull _instigator) then {
    _instigator = [_unit, _causedBy] call FUNC(getInstigator);
  };

  _unitID = _unit getVariable [QGVARMAIN(id), -1];
  if (_unitID == -1) exitWith {};
  private _eventData = [GVAR(captureFrameNo), "hit", _unitID, ["null"], -1];

  if (!isNull _instigator) then {
    _causedById = _causedBy getVariable [QGVARMAIN(id), -1];
    _instigatorId = _instigator getVariable [QGVARMAIN(id), -1];

    private _causedByInfo = [];
    private _distanceInfo = 0;
    if (_causedBy isKindOf "CAManBase" && _causedById > -1) then {
      _causedByInfo = [
        _causedById,
        ([_causedBy] call FUNC(getEventWeaponText))
      ];
      _distanceInfo = round (_unit distance _causedBy);
    } else {
      if (!isNull _instigator && _causedBy != _instigator && _instigator isKindOf "CAManBase" && _instigatorId > -1) then {
        _causedByInfo = [
          _instigatorId,
          ([_instigator] call FUNC(getEventWeaponText))
        ];
        _distanceInfo = round (_unit distance _instigator);
      } else {
        _causedByInfo = [_causedById];
        _distanceInfo = round (_unit distance _causedBy);
      };
    };
    _eventData = [
      GVAR(captureFrameNo),
      "hit",
      _unitID,
      _causedByInfo,
      _distanceInfo
    ];
  };

  OCAPEXTLOG(_eventData);
  [":EVENT:", _eventData] call EFUNC(extension,sendData);
};