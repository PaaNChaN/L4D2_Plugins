/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.

	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.

	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#if defined _l4d2_picker
 #endinput
#endif
#define _l4d2_picker


/**
 * This function is for want to know if Picking Sequence is activating.
 *
 * @return				true if in Picking Sequence, false otherwise.
 */
native bool Picker_IsPicking();


/**
 * This function is for want to know client is joined player or not.
 *
 * @param client			Client Index.
 * @return				true if Client is Joined player, false otherwise.
 */
native bool Picker_IsJoinPlayer(int client);


/**
 * This function is for want to know who is first picker.
 * 0 = 1st Picker: Survivors / 2nd Picker: Infected
 * 1 = 1st Picker: Infected / 2nd Picker: Survivors
 * 
 * @return				0 or 1.
 */
native int Picker_GetFirstAndSecondPicker();

public SharedPlugin __pl_l4d2_picker = 
{
	name = "l4d2_picker",
	file = "l4d2_picker.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_picker_SetNTVOptional()
{
	MarkNativeAsOptional("Picker_IsPicking");
	MarkNativeAsOptional("Picker_IsJoinPlayer");
	MarkNativeAsOptional("Picker_GetFirstAndSecondPicker");
}
#endif