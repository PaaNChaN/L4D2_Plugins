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
#if defined _l4d2_name_tag_included
 #endinput
#endif
#define _l4d2_name_tag_included


/**
 * This function is get the client NameTag.
 *
 * @param int    client   Client Index.
 * @param char[] nametag  Buffer to store the client's NameTag.
 * @param int    maxlen   Maximum length of string buffer (includes NULL terminator)
 */
native bool LNT_GetNameTag(int client, char[] nametag, int maxlen);


public SharedPlugin __pl_l4d2_name_tag =
{
	name = "l4d2_name_tag",
	file = "l4d2_name_tag.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_name_tag_SetNTVOptional()
{
	MarkNativeAsOptional("LNT_GetNameTag");
}
#endif