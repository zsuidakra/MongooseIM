%%==============================================================================
%% Copyright 2012 Erlang Solutions Ltd.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%% http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%==============================================================================

-module(muc_SUITE).
-compile(export_all).

-include_lib("escalus/include/escalus.hrl").
-include_lib("escalus/include/escalus_xmlns.hrl").
-include_lib("common_test/include/ct.hrl").
-include_lib("exml/include/exml.hrl").

-define(MUC_HOST, <<"muc.localhost">>).
-define(MUC_CLIENT_HOST, <<"localhost/res1">>).
-define(PASSWORD, <<"password">>).

-define(NS_MUC_REQUEST, <<"http://jabber.org/protocol/muc#request">>).
-define(NS_MUC_ROOMCONFIG, <<"http://jabber.org/protocol/muc#roomconfig">>).

%%--------------------------------------------------------------------
%% Suite configuration
%%--------------------------------------------------------------------

all() -> [
          {group, disco},
          {group, moderator},
          {group, admin},
          {group, admin_membersonly},
          {group, occupant},
          {group, owner},
          {group, room_management}
         ].

groups() -> [
             {disco, [sequence], [
                                  disco_service,
                                  disco_features,
                                  disco_rooms,
                                  disco_info,
                                  disco_items
                                 ]},
             {moderator, [sequence], [
                                      moderator_subject,
                                      %% fails, see testcase:
                                      %% moderator_subject_unauthorized,
                                      moderator_kick,
                                      moderator_kick_unauthorized,
                                      moderator_voice,
                                      moderator_voice_unauthorized,
                                      moderator_voice_list
                                      %% unfinished, fails
                                      %% moderator_voice_approval
                                     ]},
             {admin, [sequence], [
                                  admin_ban,
                                  admin_ban_list,
                                  %% fails, see testcase
                                  %% admin_ban_higher_user,
                                  admin_membership,
                                  admin_member_list,
                                  admin_moderator,
                                  admin_moderator_revoke_owner,
                                  admin_moderator_list
                                 ]},
             {admin_membersonly, [sequence], [
                                              admin_mo_revoke
                                              %% fails, see testcase
                                              %% admin_mo_invite
                                              %% fails, see testcase
                                              %% admin_mo_invite_mere
                                             ]},
             {occupant, [sequence], [
                                    groupchat_user_enter,
                                    groupchat_user_enter_no_nickname,
                                    muc_user_enter,
                                    deny_access_to_password_protected_room,
                                    enter_password_protected_room,
                                    deny_accesss_to_memebers_only_room,
                                    deny_entry_to_a_banned_user,
                                    deny_entry_nick_conflict,
                                    send_to_all
                                    ]},
             {owner, [sequence], [
                                  %% failing, see testcase for explanation
                                  %room_creation_not_allowed,
                                  %cant_enter_locked_room
                                  create_instant_room,
                                  create_reserved_room,
                                  owner_grant_revoke,
                                  owner_list,
                                  %% fails, see testcase
                                  %% owner_unauthorized
                                  admin_grant_revoke,
                                  admin_list,
                                  %% fails, see testcase
                                  %% admin_unauthorized
                                  destroy
                                  %% fails, see testcase
                                  %% destroy_unauthorized
                                 ]},
             {room_management, [sequence], [
                                            create_and_destroy_room
                                           ]}
            ].

suite() ->
    escalus:suite().

%%--------------------------------------------------------------------
%% Init & teardown
%%--------------------------------------------------------------------

init_per_suite(Config) ->
    escalus:init_per_suite(Config).

end_per_suite(Config) ->
    escalus:end_per_suite(Config).

init_per_group(moderator, Config) ->
    RoomName = <<"alicesroom">>,
    RoomNick = <<"alicesnick">>,
    Config1 = escalus:create_users(Config),
    [Alice | _] = ?config(escalus_users, Config1),
    start_room(Config1, Alice, RoomName, RoomNick,
        [{persistent, true}, {allow_change_subj, false}, {moderated, true},
         {members_by_default, false}]);

init_per_group(admin, Config) ->
    RoomName = <<"alicesroom">>,
    RoomNick = <<"alicesnick">>,
    Config1 = escalus:create_users(Config),
    [Alice | _] = ?config(escalus_users, Config1),
    start_room(Config1, Alice, RoomName, RoomNick, [{persistent, true}]);

init_per_group(admin_membersonly, Config) ->
    RoomName = <<"alicesroom">>,
    RoomNick = <<"alicesnick">>,
    Config1 = escalus:create_users(Config),
    [Alice | _] = ?config(escalus_users, Config1),
    start_room(Config1, Alice, RoomName, RoomNick, [{persistent, true},
        {members_only, true}]);

init_per_group(disco, Config) ->
    Config1 = escalus:create_users(Config),
    [Alice | _] = ?config(escalus_users, Config1),
    start_room(Config1, Alice, <<"alicesroom">>, <<"aliceonchat">>,
        [{persistent, true}]);

init_per_group(_GroupName, Config) ->
    escalus:create_users(Config).

end_per_group(moderator, Config) ->
    destroy_room(Config),
    escalus:delete_users(Config);

end_per_group(admin, Config) ->
    destroy_room(Config),
    escalus:delete_users(Config);

end_per_group(admin_membersonly, Config) ->
    destroy_room(Config),
    escalus:delete_users(Config);

end_per_group(disco, Config) ->
    destroy_room(Config),
    escalus:delete_users(Config);

end_per_group(_GroupName, Config) ->
    escalus:delete_users(Config).

init_per_testcase(CaseName = destroy_unauthorized, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, [{persistent, true}]),
    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName = destroy, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, [{persistent, true}]),
    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName = admin_unauthorized, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, [{persistent, true}]),
    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName = admin_list, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, [{persistent, true}]),
    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName = admin_grant_revoke, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, [{persistent, true}]),
    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName = owner_unauthorized, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, [{persistent, true}]),
    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName = owner_list, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, [{persistent, true}]),
    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName = owner_grant_revoke, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, [{persistent, true}]),
    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName = groupchat_user_enter, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, [{persistent, true}]),
    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName = groupchat_user_enter_no_nickname, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, []),
    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName = muc_user_enter, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, []),
    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName = enter_non_anonymous_room, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, [{anonymous, false}]),
    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName = deny_access_to_password_protected_room, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    %{password_protected, Password}?
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, [{password_protected, true}]),
    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName = enter_password_protected_room, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, [{password_protected, true}, {password, ?PASSWORD}]),
    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName = deny_accesss_to_memebers_only_room, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, [{members_only, true}]),
    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName =deny_entry_to_a_banned_user, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, []),
    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName =deny_entry_nick_conflict, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, []),
    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName =deny_entry_user_limit_reached, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, [{max_users, 1}]),
    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName =send_to_all, Config) ->
    [Alice | _] = ?config(escalus_users, Config),
    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"alice">>, []),
    escalus:init_per_testcase(CaseName, Config1);

%init_per_testcase(CaseName =deny_entry_locked_room, Config) ->
%    escalus:init_per_testcase(CaseName, Config);

%init_per_testcase(CaseName =enter_room_with_logging, Config) ->
%    [Alice | _] = ?config(escalus_users, Config),
%    Config1 = start_room(Config, Alice, <<"alicesroom">>, <<"aliceonchat">>, [{logging, true}]),
%    escalus:init_per_testcase(CaseName, Config1);

init_per_testcase(CaseName, Config) ->
    escalus:init_per_testcase(CaseName, Config).

end_per_testcase(CaseName = destroy_unauthorized, Config) ->
    escalus:end_per_testcase(CaseName, Config);

end_per_testcase(CaseName = destroy, Config) ->
    escalus:end_per_testcase(CaseName, Config);

end_per_testcase(CaseName = admin_unauthorized, Config) ->
    destroy_room(Config),
    escalus:end_per_testcase(CaseName, Config);

end_per_testcase(CaseName = admin_list, Config) ->
    destroy_room(Config),
    escalus:end_per_testcase(CaseName, Config);

end_per_testcase(CaseName = admin_grant_revoke, Config) ->
    destroy_room(Config),
    escalus:end_per_testcase(CaseName, Config);

end_per_testcase(CaseName = owner_unauthorized, Config) ->
    destroy_room(Config),
    escalus:end_per_testcase(CaseName, Config);

end_per_testcase(CaseName = owner_list, Config) ->
    destroy_room(Config),
    escalus:end_per_testcase(CaseName, Config);

end_per_testcase(CaseName = owner_grant_revoke, Config) ->
    destroy_room(Config),
    escalus:end_per_testcase(CaseName, Config);

end_per_testcase(CaseName = groupchat_user_enter, Config) ->
    destroy_room(Config),
    escalus:end_per_testcase(CaseName, Config);

end_per_testcase(CaseName = groupchat_user_enter_no_nickname, Config) ->
    destroy_room(Config),
    escalus:end_per_testcase(CaseName, Config);

end_per_testcase(CaseName = muc_user_enter, Config) ->
    destroy_room(Config),
    escalus:end_per_testcase(CaseName, Config);

end_per_testcase(CaseName = deny_access_to_password_protected_room, Config) ->
    destroy_room(Config),
    escalus:end_per_testcase(CaseName, Config);

end_per_testcase(CaseName = enter_password_protected_room, Config) ->
    destroy_room(Config),
    escalus:end_per_testcase(CaseName, Config);

end_per_testcase(CaseName = deny_accesss_to_memebers_only_room, Config) ->
    destroy_room(Config),
    escalus:end_per_testcase(CaseName, Config);

end_per_testcase(CaseName =deny_entry_to_a_banned_user, Config) ->
    destroy_room(Config),
    escalus:end_per_testcase(CaseName, Config);

end_per_testcase(CaseName =deny_entry_nick_conflict, Config) ->
    destroy_room(Config),
    escalus:end_per_testcase(CaseName, Config);

end_per_testcase(CaseName =deny_entry_user_limit_reached, Config) ->
    destroy_room(Config),
    escalus:end_per_testcase(CaseName, Config);

%end_per_testcase(CaseName =deny_entry_locked_room, Config) ->
%    destroy_room(Config),
%    escalus:end_per_testcase(CaseName, Config);

%end_per_testcase(CaseName =enter_room_with_logging, Config) ->
%    destroy_room(Config),
%    escalus:end_per_testcase(CaseName, Config);

end_per_testcase(CaseName =send_to_all, Config) ->
    destroy_room(Config),
    escalus:end_per_testcase(CaseName, Config);

end_per_testcase(CaseName, Config) ->
    escalus:end_per_testcase(CaseName, Config).

%%--------------------------------------------------------------------
%%  Moderator use case tests
%%
%%  Tests the usecases described here :
%%  http://xmpp.org/extensions/xep-0045.html/#moderator
%%--------------------------------------------------------------------

%%  Examples 84-85
moderator_subject(Config) ->
    escalus:story(Config, [1], fun(Alice) ->
        %% Alice joins room
        escalus:send(Alice, stanza_muc_enter_room(?config(room, Config), <<"alice">>)),
        escalus:wait_for_stanzas(Alice, 2),

        %% Alice sets room subject
        escalus:send(Alice,
            stanza_room_subject(?config(room,Config), <<"Lets have a chat!">>)),

        %% Alice receives subject change message
        Message = escalus:wait_for_stanza(Alice),
        true = is_subject_message(Message, <<"Lets have a chat!">>),
        escalus:assert(is_stanza_from,
            [room_address(?config(room,Config), <<"alice">>)], Message)
    end).

%%  Example 87
%%  This test fails
%%  According to XEP error message should be from chatroom@service/nick,
%%  however ejabberd provides it from chatroom@service
moderator_subject_unauthorized(Config) ->
    escalus:story(Config, [1,1], fun(_Alice, Bob) ->
        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 2),

        %% Bob tries to set the room subject
        escalus:send(Bob,
            stanza_room_subject(?config(room,Config), <<"Lets have a chat!">>)),

        %% Bob should receive an error
        Error = escalus:wait_for_stanza(Bob),
        escalus:assert(is_error, [<<"auth">>, <<"forbidden">>], Error),
        escalus:assert(is_stanza_from,
          [room_address(?config(room, Config), <<"bob">>)], Error)
    end).

%%  Examples 89-92
%%  Apparently user has to be in the room to kick someone, however XEP doesn't need that
moderator_kick(Config) ->
    escalus:story(Config, [1,1], fun(Alice, Bob) ->
        %% Alice joins room
        escalus:send(Alice, stanza_muc_enter_room(?config(room, Config), <<"alice">>)),
        escalus:wait_for_stanzas(Alice, 2),
        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 3),
        %% Skip Bob's presence
        escalus:wait_for_stanza(Alice),

        %% Alice kicks Bob
        escalus:send(Alice, stanza_set_roles(
            ?config(room,Config), [{<<"bob">>,<<"none">>}])),

        %% Alice receives both iq result and Bob's unavailable presence
        Pred = fun(Stanza) ->
            is_unavailable_presence(Stanza, <<"307">>) andalso
            escalus_pred:is_stanza_from(
                room_address(?config(room, Config), <<"bob">>), Stanza)
        end,
        escalus:assert_many([is_iq_result, Pred],
          escalus:wait_for_stanzas(Alice, 2)),

        %% Bob receives his presence
        escalus:assert(Pred, escalus:wait_for_stanza(Bob))
    end).

%%  Example 93
moderator_kick_unauthorized(Config) ->
    escalus:story(Config, [1,1], fun(Alice, Bob) ->
        %% Alice joins room
        escalus:send(Alice, stanza_muc_enter_room(?config(room, Config), <<"alice">>)),
        escalus:wait_for_stanzas(Alice, 2),
        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 3),
        %% Skip Bob's presence
        escalus:wait_for_stanza(Alice),

        %% Bob tries to kick Alice
        escalus:send(Bob, stanza_set_roles(
            ?config(room,Config), [{<<"alice">>,<<"none">>}])),

        %% Bob should get an error
        Error = escalus:wait_for_stanza(Bob),
        escalus:assert(is_error, [<<"cancel">>,<<"not-allowed">>], Error),
        escalus:assert(is_stanza_from, [room_address(?config(room, Config))], Error)
    end).

%%  Examples 94-101
moderator_voice(Config) ->
    escalus:story(Config, [1,1], fun(Alice, Bob) ->
        %% Alice joins room
        escalus:send(Alice, stanza_muc_enter_room(?config(room, Config), <<"alice">>)),
        escalus:wait_for_stanzas(Alice, 2),
        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 3),
        %% Skip Bob's presence
        escalus:wait_for_stanza(Alice),

        %% Alice grants voice to Bob
        escalus:send(Alice, stanza_set_roles(?config(room,Config),
            [{<<"bob">>,<<"participant">>}])),

        %% Alice receives success information and new Bob's presence
        Pred = fun(Stanza) ->
            is_presence_with_role(Stanza, <<"participant">>) andalso
            escalus_pred:is_stanza_from(
              room_address(?config(room, Config), <<"bob">>), Stanza)
        end,
        escalus:assert_many([is_iq_result, Pred],
            escalus:wait_for_stanzas(Alice, 2)),

        %% Bob should receive his new presence
        escalus:assert(Pred, escalus:wait_for_stanza(Bob)),

        %% Revoke Bob's voice
        escalus:send(Alice, stanza_set_roles(?config(room,Config),
            [{<<"bob">>,<<"visitor">>}])),

        %% Alice receives success information and new Bob's presence
        Pred2 = fun(Stanza) ->
            is_presence_with_role(Stanza, <<"visitor">>) andalso
            escalus_pred:is_stanza_from(
                room_address(?config(room, Config), <<"bob">>), Stanza)
        end,
        escalus:assert_many([is_iq_result, Pred2],
            escalus:wait_for_stanzas(Alice, 2)),

        %% Bob should receive his new presence
        escalus:assert(Pred2, escalus:wait_for_stanza(Bob))
    end).

%%  Example 102, 107
moderator_voice_unauthorized(Config) ->
    escalus:story(Config, [1,1], fun(Alice, Bob) ->
        %% Alice joins room
        escalus:send(Alice, stanza_muc_enter_room(?config(room, Config), <<"alice">>)),
        escalus:wait_for_stanzas(Alice, 2),
        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 3),
        %% Skip Bob's presence
        escalus:wait_for_stanza(Alice),

        %% Bob tries to revoke voice from Alice
        escalus:send(Bob, stanza_set_roles(?config(room,Config),
            [{<<"alice">>,<<"visitor">>}])),

        %% Bob should get an error
        Error = escalus:wait_for_stanza(Bob),
        escalus:assert(is_error, [<<"cancel">>, <<"not-allowed">>], Error),
        escalus:assert(is_stanza_from, [room_address(?config(room, Config))], Error)
    end).

%%  Examples 103-106
%%  ejabberd behaves strange, responds that owner doesn't have moderator privileges
%%  if she isn't in the room
moderator_voice_list(Config) ->
    escalus:story(Config, [1,1,1], fun(Alice, Bob, Kate) ->
        %% Alice joins room
        escalus:send(Alice, stanza_muc_enter_room(?config(room, Config), <<"alice">>)),
        escalus:wait_for_stanzas(Alice, 2),
        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 3),
        %% Kate joins room
        escalus:send(Kate, stanza_muc_enter_room(?config(room, Config), <<"kate">>)),
        escalus:wait_for_stanzas(Kate, 4),
        %% Skip Kate's presence
        escalus:wait_for_stanza(Bob),
        %% Skip Kate's and Bob's presences
        escalus:wait_for_stanzas(Alice, 3),

        %% Alice requests voice list
        escalus:send(Alice,
          stanza_role_list_request(?config(room, Config), <<"participant">>)),
        List = escalus:wait_for_stanza(Alice),
        escalus:assert(is_iq_result, List),
        escalus:assert(is_stanza_from, [room_address(?config(room, Config))], List),
        %% List should be empty
        [] = List#xmlelement.body,

        %% Grant voice to Bob and Kate
        escalus:send(Alice, stanza_set_roles(?config(room, Config),
              [{<<"bob">>, <<"participant">>}, {<<"kate">>,<<"participant">>}])),

        %% Alice receives confirmation and Bob's and Kate's new presences
        Preds = [fun(Stanza) ->
            is_presence_with_role(Stanza, <<"participant">>) andalso
            escalus_pred:is_stanza_from(
                room_address(?config(room, Config), <<"bob">>), Stanza)
        end,
        fun(Stanza) ->
            is_presence_with_role(Stanza, <<"participant">>) andalso
            escalus_pred:is_stanza_from(
                room_address(?config(room, Config), <<"kate">>), Stanza)
        end],
        escalus:assert_many([is_iq_result | Preds],
            escalus:wait_for_stanzas(Alice, 3)),

        %% Bob and Kates get their presences
        escalus:assert_many(Preds, escalus:wait_for_stanzas(Bob, 2)),
        escalus:assert_many(Preds, escalus:wait_for_stanzas(Kate, 2)),

        %% Alice requests voice list again
        escalus:send(Alice,
          stanza_role_list_request(?config(room, Config), <<"participant">>)),
        List2 = escalus:wait_for_stanza(Alice),
        escalus:assert(is_iq_result, List2),
        escalus:assert(is_stanza_from, [room_address(?config(room, Config))], List2),
        %% Bob and Kate should be on it
        true = is_iq_with_jid(List2, Bob),
        true = is_iq_with_jid(List2, Kate),

        %% Revoke Bob's and Kate's voices
        escalus:send(Alice, stanza_set_roles(?config(room, Config),
              [{<<"bob">>, <<"visitor">>}, {<<"kate">>,<<"visitor">>}])),

        %% Alice receives confirmation and Bob's and Kate's new presences
        Preds2 = [fun(Stanza) ->
            is_presence_with_role(Stanza, <<"visitor">>) andalso
            escalus_pred:is_stanza_from(
                room_address(?config(room, Config), <<"bob">>), Stanza)
        end,
        fun(Stanza) ->
            is_presence_with_role(Stanza, <<"visitor">>) andalso
            escalus_pred:is_stanza_from(
                room_address(?config(room, Config), <<"kate">>), Stanza)
        end],
        escalus:assert_many([is_iq_result | Preds2],
            escalus:wait_for_stanzas(Alice, 3)),

        %% Bob and Kates get their presences
        escalus:assert_many(Preds2, escalus:wait_for_stanzas(Bob, 2)),
        escalus:assert_many(Preds2, escalus:wait_for_stanzas(Kate, 2))
    end).

%%  This test fails, moderator never gets voice approval form
%%  Examples 108-109
moderator_voice_approval(Config) ->
    escalus:story(Config, [1, 1], fun(Alice, Bob) ->
        %% Alice joins room
        escalus:send(Alice, stanza_muc_enter_room(?config(room, Config), <<"alice">>)),
        escalus:wait_for_stanzas(Alice, 2),
        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 3),
        %% Skip Bob's presence
        escalus:wait_for_stanza(Alice),

        %% Bob sends voice request
        Request = stanza_voice_request_form(?config(room, Config)),
        error_logger:info_msg("~p~n", [Request]),
        escalus:send(Bob, stanza_voice_request_form(?config(room, Config))),

        %% Alice should get the request
        _Form = escalus:wait_for_stanza(Alice)

        %% TODO check if form is properly formed, submit approval, check new presence
    end).


%%--------------------------------------------------------------------
%%  Admin use case tests
%%
%%  Tests the usecases described here :
%%  http://xmpp.org/extensions/xep-0045.html/#admin
%%--------------------------------------------------------------------

%%    Examples 110-114
admin_ban(Config) ->
    escalus:story(Config, [1,1,1], fun(Alice, Bob, Kate) ->
        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 2),
        %% Kate joins room
        escalus:send(Kate, stanza_muc_enter_room(?config(room, Config), <<"kate">>)),
        escalus:wait_for_stanzas(Kate, 3),
        %% Skip Kate's presence
        escalus:wait_for_stanza(Bob),

        %% Alice bans Bob
        escalus:send(Alice, stanza_ban_user(Bob, ?config(room, Config))),
        
        %% Alice receives confirmation
        escalus:assert(is_iq_result, escalus:wait_for_stanza(Alice)),

        %% Bob receives outcast presence
        Outcast = escalus:wait_for_stanza(Bob),
        escalus:assert(is_presence_with_type, [<<"unavailable">>], Outcast),
        escalus:assert(is_stanza_from,
            [room_address(?config(room, Config), <<"bob">>)], Outcast),
        true = is_presence_with_status_code(Outcast, <<"301">>),
        true = is_presence_with_affiliation(Outcast, <<"outcast">>),
        true = is_presence_with_role(Outcast, <<"none">>),

        %% Kate receives Bob's outcast presence
        BobOutcast = escalus:wait_for_stanza(Kate),
        escalus:assert(is_presence_with_type, [<<"unavailable">>], BobOutcast),
        true = is_presence_with_affiliation(BobOutcast, <<"outcast">>),
        true = is_presence_with_role(BobOutcast, <<"none">>),
        escalus:assert(is_stanza_from, [room_address(?config(room, Config), <<"bob">>)],
            BobOutcast)
        %% ejabberd doesn't send jid attribute in presence as in ex. 114
    end).

%%    Example 115
%%    This test fails
%%    Reponse 'from' field should be full JID, ejabberd provides chatroom JID
admin_ban_higher_user(Config) ->
    escalus:story(Config, [1, 1], fun(Alice, Bob) ->
        %% Bob tries to ban Alice
        escalus:send(Bob, stanza_ban_user(Alice, ?config(room, Config))),

        %% Bob receives an error
        Error = escalus:wait_for_stanza(Bob),
        escalus:assert(is_error, [<<"cancel">>, <<"not-allowed">>], Error),
        escalus:assert(is_stanza_from,
            [escalus_utils:get_jid(Bob)], Error)
    end).

%%    Examples 116-119
admin_ban_list(Config) ->
    escalus:story(Config, [1, 1], fun(Alice, Bob) ->
        %% Alice requests ban list
        escalus:send(Alice, stanza_ban_list_request(?config(room, Config))),
        List = escalus:wait_for_stanza(Alice),
        escalus:assert(is_iq_result, List),

        %% Bob should be banned
        true = is_iq_with_affiliation(List, <<"outcast">>),
        true = is_iq_with_short_jid(List, Bob),

        %% Remove Bob's ban
        stanza_to_room(escalus_stanza:iq_set(?NS_MUC_ADMIN, []), ?config(room, Config)),
        Items = [{<<"none">>, escalus_utils:get_short_jid(Bob)}],
        escalus:send(Alice, stanza_admin_list(?config(room, Config), Items)),
        escalus:assert(is_iq_result, escalus:wait_for_stanza(Alice)),

        %% Request again
        escalus:send(Alice, stanza_ban_list_request(?config(room, Config))),
        List2 = escalus:wait_for_stanza(Alice),

        %% Noone should be banned
        escalus:assert(is_stanza_from, [room_address(?config(room, Config))],
            List2),
        [] = List2#xmlelement.body
    end).

%%  Examples 120-127
admin_membership(Config) ->
    escalus:story(Config, [1,1,1], fun(Alice, Bob, Kate) ->
        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 2),
        %% Kate joins room
        escalus:send(Kate, stanza_muc_enter_room(?config(room, Config), <<"kate">>)),
        escalus:wait_for_stanzas(Kate, 3),
        %% Skip Kate's presence
        escalus:wait_for_stanza(Bob),

        %% Alice grants membership to Bob
        Items = [{<<"member">>, escalus_utils:get_short_jid(Bob)}],
        escalus:send(Alice, stanza_admin_list(?config(room, Config), Items)),
        escalus:assert(is_iq_result, escalus:wait_for_stanza(Alice)),

        %% Bob receives his notice
        Bobs = escalus:wait_for_stanza(Bob),
        true = is_presence_with_affiliation(Bobs, <<"member">>),
        escalus:assert(is_stanza_from,
          [room_address(?config(room, Config), <<"bob">>)], Bobs),

        %% Kate receives Bob's notice
        Kates = escalus:wait_for_stanza(Kate),
        true = is_presence_with_affiliation(Kates, <<"member">>),
        escalus:assert(is_stanza_from,
          [room_address(?config(room, Config), <<"bob">>)], Kates),

        %% Alice revokes Bob's membership
        Items2 = [{<<"none">>, escalus_utils:get_short_jid(Bob)}],
        escalus:send(Alice, stanza_admin_list(?config(room, Config), Items2)),
        escalus:assert(is_iq_result, escalus:wait_for_stanza(Alice)),

        %% Bob receives his loss of membership presence
        Bobs2 = escalus:wait_for_stanza(Bob),
        true = is_presence_with_affiliation(Bobs2, <<"none">>),
        escalus:assert(is_stanza_from,
            [room_address(?config(room,Config), <<"bob">>)], Bobs2),

        %% Kate receives Bob's loss of membership presence
        Kates2 = escalus:wait_for_stanza(Kate),
        true = is_presence_with_affiliation(Kates2, <<"none">>),
        escalus:assert(is_stanza_from,
            [room_address(?config(room,Config), <<"bob">>)], Kates2)
    end).

%%  Examples 129-136
admin_member_list(Config) ->
    escalus:story(Config, [1,1,1], fun(Alice, Bob, Kate) ->
        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 2),
        %% Kate joins room
        escalus:send(Kate, stanza_muc_enter_room(?config(room, Config), <<"kate">>)),
        escalus:wait_for_stanzas(Kate, 3),
        %% Skip Kate's presence
        escalus:wait_for_stanza(Bob),

        %% Alice requests member list
        escalus:send(Alice, stanza_affiliation_list_request(
            ?config(room, Config), <<"member">>)),
        List = escalus:wait_for_stanza(Alice),
        escalus:assert(is_iq_result, List),

        %% List should be empty
        [] = List#xmlelement.body,
        escalus:assert(is_stanza_from, [room_address(?config(room, Config))], List),

        %% Make Bob a member
        Items = [{<<"member">>, escalus_utils:get_short_jid(Bob)}],
        escalus:send(Alice, stanza_admin_list(?config(room, Config), Items)),
        escalus:assert(is_iq_result, escalus:wait_for_stanza(Alice)),

        %% Bob receives his notice
        Bobs = escalus:wait_for_stanza(Bob),
        true = is_presence_with_affiliation(Bobs, <<"member">>),
        escalus:assert(is_stanza_from,
          [room_address(?config(room, Config), <<"bob">>)], Bobs),

        %% Kate receives Bob's notice
        Kates = escalus:wait_for_stanza(Kate),
        true = is_presence_with_affiliation(Kates, <<"member">>),
        escalus:assert(is_stanza_from,
            [room_address(?config(room, Config), <<"bob">>)], Kates),

        %% Request again
        escalus:send(Alice, stanza_affiliation_list_request(
              ?config(room, Config), <<"member">>)),
        List2 = escalus:wait_for_stanza(Alice),
        escalus:assert(is_iq_result, List2),

        %% Bob should be on the list
        true = is_iq_with_affiliation(List2, <<"member">>),
        true = is_iq_with_short_jid(List2, Bob),

        %% Revoke Bob's membership and make Kate a member
        Items2 = [{<<"none">>, escalus_utils:get_short_jid(Bob)},
            {<<"member">>, escalus_utils:get_short_jid(Kate)}],
        escalus:send(Alice, stanza_admin_list(?config(room,Config), Items2)),
        escalus:assert(is_iq_result, escalus:wait_for_stanza(Alice)),

        %% Bob receives his and Kate's presence
        Preds = [
            fun(Stanza) ->
                escalus_pred:is_stanza_from(
                  room_address(?config(room, Config), <<"kate">>),Stanza) andalso
                is_presence_with_affiliation(Stanza, <<"member">>)
            end,
            fun(Stanza) ->
                escalus_pred:is_stanza_from(
                  room_address(?config(room, Config), <<"bob">>),Stanza) andalso
                is_presence_with_affiliation(Stanza, <<"none">>)
            end
        ],
        escalus:assert_many(Preds, escalus:wait_for_stanzas(Bob, 2)),

        %% Kate receives her and Bob's presence
        escalus:assert_many(Preds, escalus:wait_for_stanzas(Kate, 2))
  end).

%%  Examples 137-145
admin_moderator(Config) ->
    escalus:story(Config, [1,1,1], fun(Alice, Bob, Kate) ->
        %% Alice joins room
        escalus:send(Alice, stanza_muc_enter_room(?config(room, Config), <<"alice">>)),
        escalus:wait_for_stanzas(Alice, 2),
        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 3),
        %% Kate joins room
        escalus:send(Kate, stanza_muc_enter_room(?config(room, Config), <<"kate">>)),
        escalus:wait_for_stanzas(Kate, 4),
        %% Skip Kate's presence
        escalus:wait_for_stanza(Bob),
        %% Skip Kate's and Bob's presences
        escalus:wait_for_stanzas(Alice, 3),

        %% Grant bob moderator status
        escalus:send(Alice, stanza_set_roles(
            ?config(room, Config), [{<<"bob">>,<<"moderator">>}])),
        escalus:assert_many([is_iq_result, is_presence], escalus:wait_for_stanzas(Alice, 2)),

        %% Bob receives his notice
        Bobs = escalus:wait_for_stanza(Bob),
        true = is_presence_with_role(Bobs, <<"moderator">>),
        escalus:assert(is_stanza_from,
          [room_address(?config(room, Config), <<"bob">>)], Bobs),

        %% Kate receives Bob's notice
        Kates = escalus:wait_for_stanza(Kate),
        true = is_presence_with_role(Kates, <<"moderator">>),
        escalus:assert(is_stanza_from,
            [room_address(?config(room, Config), <<"bob">>)], Kates),

        %% Revoke bob moderator status
        Pred = fun(Stanza) ->
                escalus_pred:is_stanza_from(
                  room_address(?config(room, Config), <<"bob">>),Stanza) andalso
                is_presence_with_role(Stanza, <<"participant">>)
        end,

        escalus:send(Alice, stanza_set_roles(
            ?config(room, Config), [{<<"bob">>, <<"participant">>}])),
        escalus:assert_many([is_iq_result, Pred], escalus:wait_for_stanzas(Alice, 2)),

        %% Bob receives his loss of moderator presence
        Bobs2 = escalus:wait_for_stanza(Bob),
        true = is_presence_with_role(Bobs2, <<"participant">>),
        escalus:assert(is_stanza_from,
            [room_address(?config(room,Config), <<"bob">>)], Bobs2),

        %% Kate receives Bob's loss of moderator presence
        Kates2 = escalus:wait_for_stanza(Kate),
        true = is_presence_with_role(Kates2, <<"participant">>),
        escalus:assert(is_stanza_from,
            [room_address(?config(room,Config), <<"bob">>)], Kates2)

    end).

%%  Examples 145, 150
admin_moderator_revoke_owner(Config) ->
    escalus:story(Config, [1], fun(Alice) ->
        %% Alice joins room
        escalus:send(Alice, stanza_muc_enter_room(?config(room, Config), <<"alice">>)),
        escalus:wait_for_stanzas(Alice, 2),

        %% Alice tries to revoke moderator status from herself
        escalus:send(Alice, stanza_set_roles(
             ?config(room, Config), [{<<"alice">>, <<"participant">>}])),

        %% Should be an error
        Error = escalus:wait_for_stanza(Alice),
        escalus:assert(is_error, [<<"cancel">>, <<"not-allowed">>], Error),
        escalus:assert(is_stanza_from, [room_address(?config(room, Config))], Error)
    end).

%%  Examples 146-150
admin_moderator_list(Config) ->
    escalus:story(Config, [1,1,1], fun(Alice, Bob, Kate) ->
        %% Alice joins room
        escalus:send(Alice, stanza_muc_enter_room(?config(room, Config), <<"alice">>)),
        escalus:wait_for_stanzas(Alice, 2),
        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 3),
        %% Kate joins room
        escalus:send(Kate, stanza_muc_enter_room(?config(room, Config), <<"kate">>)),
        escalus:wait_for_stanzas(Kate, 4),
        %% Skip Kate's presence
        escalus:wait_for_stanza(Bob),
        %% Skip Kate's and Bob's presences
        escalus:wait_for_stanzas(Alice, 3),

        %% Request moderator list
        escalus:send(Alice, stanza_role_list_request(
            ?config(room, Config), <<"moderator">>)),
        List = escalus:wait_for_stanza(Alice),
        escalus:assert(is_iq_result, List),
        %% Alice should be on it
        true = is_iq_with_jid(List, Alice),
        true = is_iq_with_role(List, <<"moderator">>),

        %% Grant Bob and Kate moderators role
        Preds = [
            fun(Stanza) ->
                escalus_pred:is_stanza_from(
                  room_address(?config(room, Config), <<"kate">>),Stanza) andalso
                is_presence_with_role(Stanza, <<"moderator">>)
            end,
            fun(Stanza) ->
                escalus_pred:is_stanza_from(
                  room_address(?config(room, Config), <<"bob">>),Stanza) andalso
                is_presence_with_role(Stanza, <<"moderator">>)
            end
        ],
        escalus:send(Alice, stanza_set_roles(?config(room, Config),
            [{<<"bob">>,<<"moderator">>},{<<"kate">>,<<"moderator">>}])),
        escalus:assert_many([is_iq_result | Preds], escalus:wait_for_stanzas(Alice,3)),

        %% Bob receives his and Kate's moderator presence
        escalus:assert_many(Preds, escalus:wait_for_stanzas(Bob,2)),

        %% Kate receives her and Bob's moderator presence
        escalus:assert_many(Preds, escalus:wait_for_stanzas(Kate,2)),

        %% Request again
        escalus:send(Alice, stanza_role_list_request(
            ?config(room, Config), <<"moderator">>)),
        List2 = escalus:wait_for_stanza(Alice),
        escalus:assert(is_iq_result, List2),

        %% Alice, Bob and Kate should be on it
        true = is_iq_with_jid(List2, Alice),
        true = is_iq_with_jid(List2, Bob),
        true = is_iq_with_jid(List2, Kate),

        %% Revoke Bob's and Kate's roles
        Preds2 = [
            fun(Stanza) ->
                escalus_pred:is_stanza_from(
                  room_address(?config(room, Config), <<"kate">>),Stanza) andalso
                is_presence_with_role(Stanza, <<"participant">>)
            end,
            fun(Stanza) ->
                escalus_pred:is_stanza_from(
                  room_address(?config(room, Config), <<"bob">>),Stanza) andalso
                is_presence_with_role(Stanza, <<"participant">>)
            end
        ],
        escalus:send(Alice, stanza_set_roles(?config(room, Config),
              [{<<"bob">>,<<"participant">>},{<<"kate">>,<<"participant">>}])),
        escalus:assert_many([is_iq_result|Preds2], escalus:wait_for_stanzas(Alice,3)),

        %% Bob receives his and Kate's participant presence
        escalus:assert_many(Preds2, escalus:wait_for_stanzas(Bob,2)),

        %% Kate receives her and Bob's participant presence
        escalus:assert_many(Preds2, escalus:wait_for_stanzas(Kate,2))
    end).

%%  Example 128
admin_mo_revoke(Config) ->
    escalus:story(Config, [1,1,1], fun(Alice, Bob, Kate) ->
        %% Make Bob and Kate members
        Items = [{<<"member">>, escalus_utils:get_short_jid(Bob)},
            {<<"member">>, escalus_utils:get_short_jid(Kate)}],
        escalus:send(Alice, stanza_admin_list(?config(room,Config), Items)),
        escalus:wait_for_stanza(Alice),

        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 2),
        %% Kate joins room
        escalus:send(Kate, stanza_muc_enter_room(?config(room, Config), <<"kate">>)),
        escalus:wait_for_stanzas(Kate, 3),
        %% Skip Kate's presence
        escalus:wait_for_stanza(Bob),

        %% Alice revokes Bob's membership
        Items2 = [{<<"none">>, escalus_utils:get_short_jid(Bob)}],
        escalus:send(Alice, stanza_admin_list(?config(room, Config), Items2)),
        escalus:assert(is_iq_result, escalus:wait_for_stanza(Alice)),

        %% Skip Bob's lost of membership presence (tested in the other case)
        escalus:wait_for_stanza(Bob),

        %% Kate receives Bob's loss of unavailable presence
        Kates = escalus:wait_for_stanza(Kate),
        true = is_membership_presence(Kates, <<"none">>, <<"none">>),
        true = is_unavailable_presence(Kates, <<"321">>),
        escalus:assert(is_stanza_from,
            [room_address(?config(room, Config),<<"bob">>)], Kates)
    end).

%%  Example 134
%%  This test fails
%%  ejabberd doesn't send an invitation after adding user to a member list
admin_mo_invite(Config) ->
    escalus:story(Config, [1,1], fun(Alice, Bob) ->
        %% Make Bob a member
        Items = [{<<"member">>, escalus_utils:get_short_jid(Bob)}],
        escalus:send(Alice, stanza_admin_list(?config(room,Config), Items)),
        escalus:wait_for_stanza(Alice),

        %% Bob should receive an invitation
        Inv = escalus:wait_for_stanza(Bob),
        is_invitation(Inv),
        escalus:assert(is_stanza_from, [room_address(?config(room,Config))], Inv)
    end).

%%  Example 135
%%  This test fails
%%  ejabberd returns cancel/not-allowed error while it should return auth/forbidden according to XEP
admin_mo_invite_mere(Config) ->
    escalus:story(Config, [1,1,1], fun(Alice, Bob, Kate) ->
        %% Make Bob a member
        Items = [{<<"member">>, escalus_utils:get_short_jid(Bob)}],
        escalus:send(Alice, stanza_admin_list(?config(room,Config), Items)),
        escalus:wait_for_stanza(Alice),

        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 2),

        %% Bob tries to invite Kate
        escalus:send(Bob, stanza_mediated_invitation(?config(room,Config), Kate)),

        %% He should receive an error
        Error = escalus:wait_for_stanza(Bob),
        escalus:assert(is_error, [<<"auth">>, <<"forbidden">>], Error),
        escalus:assert(is_stanza_from, [room_address(?config(room, Config))], Error)
    end).

%%--------------------------------------------------------------------
%%  Occupant use case tests
%%
%%  Tests the usecases described here :
%%  http://xmpp.org/extensions/xep-0045.html/#user
%%
%%  Issue: the service does not broadcast the new users presence. This behaviour
%%  should be configurable and possibly enabled by default, is neither.
%%  This makes some of the use cases untestable
%%--------------------------------------------------------------------

%Example 18
groupchat_user_enter(Config) ->
    escalus:story(Config, [1, 1], fun(_Alice, Bob) ->
        Enter_room_stanza = stanza_groupchat_enter_room(<<"alicesroom">>, <<"bob">>),
        escalus:send(Bob, Enter_room_stanza),
        Presence = escalus:wait_for_stanza(Bob),
        escalus_assert:is_presence_stanza(Presence),
        From = << "alicesroom" ,"@", ?MUC_HOST/binary, "/", "bob" >>,
        From = exml_query:attr(Presence, <<"from">>)

        end).

%Example 19
%No error message sent from the server
groupchat_user_enter_no_nickname(Config) ->
    escalus:story(Config, [1, 1], fun(Alice, Bob) ->

        EnterRoomStanza = stanza_groupchat_enter_room_no_nick(<<"alicesroom">>),
        error_logger:info_msg("Enter room stanza: ~n~p", [EnterRoomStanza]),
        escalus:send(Bob, EnterRoomStanza),

        timer:sleep(1000),

        %% no error message here!
        %% processone ejabberd crashes with function clause, nick (binary) is required
        %Presence2 = escalus:wait_for_stanza(Bob),
        %escalus_assert:is_presence_stanza(Presence2),
        %From = <<"alicesroom" ,"@", ?MUC_HOST/binary, "/", "aliceonchat" >>,
        %From = exml_query:attr(Presence2, <<"from">>),

        escalus_assert:has_no_stanzas(Alice),   %!!
        escalus_assert:has_no_stanzas(Bob)

        end).

% Examples 20, 21, 22
% No broadcast message about now user's presence. The feature should be configurable, but does
% not seem to be.
muc_user_enter(Config) ->
    escalus:story(Config, [1, 1], fun(_Alice, Bob) ->
        %error_logger:info_msg("Configuration form: ~n~n~n~p~n",[stanza_configuration_form(get_from_config(room, Config), [])]),
        %Bob enters the room
        EnterRoomStanza = stanza_muc_enter_room(<<"alicesroom">>, <<"aliceonchat">>),
        error_logger:info_msg("Enter room stanza: ~n~p", [EnterRoomStanza]),
        escalus:send(Bob, EnterRoomStanza),
        Presence = escalus:wait_for_stanza(Bob),
        error_logger:info_msg("Bob's new user presence notification: ~n~p~n",[Presence]),
        escalus_assert:is_presence_stanza(Presence),
        From = << "alicesroom" ,"@", ?MUC_HOST/binary, "/", "aliceonchat" >>,
        From = exml_query:attr(Presence, <<"from">>),

        Topic = escalus:wait_for_stanza(Bob),
        error_logger:info_msg("Bobs topic notification: ~n~p~n",[Topic])
        %possible new user broadcast presence messages
    end).

% Example 23 missing
% Example 24 impossible to test due to the issues with presence broadcast.

% Example 25, 26
enter_non_anonymous_room(Config) ->
    escalus:story(Config, [1, 1], fun(_Alice,  Bob) ->
        %Bob enters the room
        Enter_room_stanza = stanza_muc_enter_room(<<"alicesroom">>, <<"aliceonchat">>),
        error_logger:info_msg("Enter room stanza: ~n~p", [Enter_room_stanza]),
        escalus:send(Bob, Enter_room_stanza),
        %A message that informs users about this room being non-anonymous.
        %Should send aprecence with a 100 staus code. Sends a simple message instead
        Message = escalus:wait_for_stanza(Bob),
        error_logger:info_msg("Info message about the room being non-anonymous: ~n~p~n", [Message]),
        Presence = escalus:wait_for_stanza(Bob),
        error_logger:info_msg("Bob's new user presence notification: ~n~p~n",[Presence]),
        escalus_assert:is_presence_stanza(Presence),
        From = << "alicesroom" ,"@", ?MUC_HOST/binary, "/", "aliceonchat" >>,
        From = exml_query:attr(Presence, <<"from">>),

        JID = <<"bob", "@", ?MUC_CLIENT_HOST/binary>>,
        error_logger:info_msg("item: ~n~p~n", [exml_query:subelement(exml_query:subelement(Presence, <<"x">>), <<"item">>)]),
        JID = exml_query:attr(
                        exml_query:subelement(
                            exml_query:subelement(Presence, <<"x">>), <<"item">>) ,<<"jid">>),
        %error_logger:info_msg("suelement : ~n~p~n", [FullJID=exml_query:subelement(<<"item">>)]),
        Topic = escalus:wait_for_stanza(Bob),
        error_logger:info_msg("Bobs topic notification: ~n~p~n",[Topic])
        %possible new user broadcast presence messages
    end).

% Semi-anonymous rooms untestable due to the issues with new user presence broadcast settings.
% (No examples, section 7.2.5)

%Example 27
deny_access_to_password_protected_room(Config) ->
    escalus:story(Config, [1, 1], fun(_Alice,  Bob) ->
        Enter_room_stanza = stanza_muc_enter_room(<<"alicesroom">>, <<"aliceonchat">>),
        error_logger:info_msg("Enter room stanza: ~n~p", [Enter_room_stanza]),
        escalus:send(Bob, Enter_room_stanza),
        Message = escalus:wait_for_stanza(Bob),
        error_logger:info_msg("No password error message: ~n~p~n", [Message]),
        escalus_assert:is_error(Message, <<"auth">>, <<"not-authorized">>)
    end).

%Example 28
enter_password_protected_room(Config) ->
    escalus:story(Config, [1, 1], fun(_Alice,  Bob) ->
        %Bob enters the room
        Enter_room_stanza = stanza_muc_enter_password_protected_room(<<"alicesroom">>, <<"aliceonchat">>, ?PASSWORD),
        error_logger:info_msg("Enter room stanza: ~n~p", [Enter_room_stanza]),
        escalus:send(Bob, Enter_room_stanza),
        Presence = escalus:wait_for_stanza(Bob),
        error_logger:info_msg("Bob's new user presence notification: ~n~p~n",[Presence]),
        escalus_assert:is_presence_stanza(Presence),
        From = << "alicesroom" ,"@", ?MUC_HOST/binary, "/", "aliceonchat" >>,
        From = exml_query:attr(Presence, <<"from">>),
        Topic = escalus:wait_for_stanza(Bob),
        error_logger:info_msg("Bobs topic notification: ~n~p~n",[Topic])
        %possible new user broadcast presence messages
    end).

%Example 29
deny_accesss_to_memebers_only_room(Config) ->
    escalus:story(Config, [1, 1], fun(_Alice,  Bob) ->
        Enter_room_stanza = stanza_muc_enter_room(<<"alicesroom">>, <<"aliceonchat">>),
        error_logger:info_msg("Enter room stanza: ~n~p", [Enter_room_stanza]),
        escalus:send(Bob, Enter_room_stanza),
        Message = escalus:wait_for_stanza(Bob),
        error_logger:info_msg("Not a member error message: ~n~p~n", [Message]),
        escalus_assert:is_error(Message, <<"auth">>, <<"registration-required">>)
    end).

%Example 30
deny_entry_to_a_banned_user(Config) ->
    escalus:story(Config, [1, 1], fun(Alice,  Bob) ->
        %% Alice bans Bob
        escalus:send(Alice, stanza_ban_user(Bob, ?config(room, Config))),
        %% Alice receives confirmation
        Stanza = escalus:wait_for_stanza(Alice),
        escalus:assert(is_iq_result, Stanza),

        Enter_room_stanza = stanza_muc_enter_room(<<"alicesroom">>, <<"aliceonchat">>),
        error_logger:info_msg("Enter room stanza: ~n~p", [Enter_room_stanza]),
        escalus:send(Bob, Enter_room_stanza),
        Message = escalus:wait_for_stanza(Bob),
        error_logger:info_msg("Banned message ~n~p~n", [Message]),
        escalus_assert:is_error(Message, <<"auth">>, <<"forbidden">>)
    end).

%Examlpe 31
deny_entry_nick_conflict(Config) -> 
    escalus:story(Config, [1, 1, 1], fun(_Alice,  Bob, Eve) ->
        Enter_room_stanza = stanza_muc_enter_room(<<"alicesroom">>, <<"bob">>),
        error_logger:info_msg("Enter room stanza: ~n~p", [Enter_room_stanza]),
        escalus:send(Bob, Enter_room_stanza),
        escalus:send(Eve, Enter_room_stanza),
        escalus:wait_for_stanzas(Bob, 2),
        Message  =escalus:wait_for_stanza(Eve),
        error_logger:info_msg("Not a member error message: ~n~p~n", [Message]),
        escalus_assert:is_error(Message, <<"cancel">>, <<"conflict">>)
    end).

%Example 32
deny_entry_user_limit_reached(Config) ->
    escalus:story(Config, [1, 1], fun(_Alice,  Bob) ->
        escalus:send(Bob,stanza_muc_enter_room(<<"alicesroom">>, <<"aliceonchat">>)),
        Message = escalus:wait_for_stanza(Bob),
        error_logger:info_msg("Not a member error message: ~n~p~n", [Message]),
        escalus_assert:is_error(Message, <<"wait">>, <<"service-unavailable">>)
    end).

%%Example 33 
%%requires creating a locked room in the init per testcase function somehow
%deny_entry_locked_room(Config) ->
%    escalus:story(Config, [1, 1], fun(_Alice,  Bob) ->
%        escalus:send(Bob,stanza_muc_enter_room(<<"alicesroom">>, <<"aliceonchat">>)),
%        Message = escalus:wait_for_stanza(Bob),
%        error_logger:info_msg("Not a member error message: ~n~p~n", [Message]),
%        escalus_assert:is_error(Message, <<"cancal">>, <<"item-not-found">>)
%    end).

% Nonexistent rooms:
% If a user seeks to enter a non-existent room, servers behaviour is undefined.
% See the xep: http://xmpp.org/extensions/xep-0045.html/#enter-nonexistent
%

%Example 34
%requires the service to send new occupant's presence to him. This does not happen
%this test is unfinished
%enter_room_with_logging(Config) ->
%    escalus:story(Config, [1, 1], fun(_Alice,  Bob) ->
%        %Bob enters the room
%        escalus:send(Bob,stanza_muc_enter_room(<<"alicesroom">>, <<"aliceonchat">>)),
%        Presence = escalus:wait_for_stanza(Bob),
%        error_logger:info_msg("Bob's new user presence notification: ~n~p~n",[Presence]),
%        escalus_assert:is_presence_stanza(Presence),
%        From = << "alicesroom" ,"@", ?MUC_HOST/binary, "/", "aliceonchat" >>,
%        From = exml_query:attr(Presence, <<"from">>),
%        escalus:wait_for_stanza(Bob)
%        %possible new user broadcast presence messages
%    end).
%

%Examples 35 - 43
%cannot be tested - missing option that enables sending history to the user


%Example 44, 45
send_to_all(Config) ->
    escalus:story(Config, [1, 1, 1], fun(_Alice,  Bob, Eve) ->
        Enter_room_stanza = stanza_muc_enter_room(<<"alicesroom">>, <<"bob">>),
        error_logger:info_msg("Enter room stanza: ~n~p", [Enter_room_stanza]),
        escalus:send(Bob, Enter_room_stanza),

        print_next_message(Bob),
        print_next_message(Bob),
        escalus_assert:has_no_stanzas(Bob),

        Enter_room_stanza2 = stanza_muc_enter_room(<<"alicesroom">>, <<"eve">>),
        error_logger:info_msg("Enter room stanza: ~n~p", [Enter_room_stanza2]),
        escalus:send(Eve, Enter_room_stanza2),

        print_next_message(Eve),
        print_next_message(Eve),
        print_next_message(Eve),
        print_next_message(Bob),

        escalus_assert:has_no_stanzas(Bob),
        escalus_assert:has_no_stanzas(Eve),

        Msg = <<"chat message">>,
        GroupchatMessage = escalus_stanza:groupchat_to(room_address(?config(room, Config)), Msg),
        error_logger:info_msg("groupchat message ~n~p~n", [GroupchatMessage]),
        escalus:send(Eve, GroupchatMessage),
        is_message_correct(?config(room, Config), <<"eve">>, Msg, escalus:wait_for_stanza(Bob)),
        is_message_correct(?config(room, Config), <<"eve">>, Msg, escalus:wait_for_stanza(Eve)),
        escalus_assert:has_no_stanzas(Bob),
        escalus_assert:has_no_stanzas(Eve)
    end).



%%--------------------------------------------------------------------
%% Tests
%%--------------------------------------------------------------------

disco_service(Config) ->
    escalus:story(Config, [1], fun(Alice) ->
        Server = escalus_client:server(Alice),
        escalus:send(Alice, escalus_stanza:service_discovery(Server)),
        Stanza = escalus:wait_for_stanza(Alice),
        escalus:assert(has_service, [?MUC_HOST], Stanza),
        escalus:assert(is_stanza_from, [escalus_config:get_config(ejabberd_domain, Config)], Stanza)
    end).

disco_features(Config) ->
    escalus:story(Config, [1], fun(Alice) ->
        escalus:send(Alice, stanza_get_features()),
        Stanza = escalus:wait_for_stanza(Alice),
        has_features(Stanza),
        escalus:assert(is_stanza_from, [?MUC_HOST], Stanza)
    end).

disco_rooms(Config) ->
    escalus:story(Config, [1], fun(Alice) ->
        escalus:send(Alice, stanza_get_rooms()),
        %% we should have 1 room, created in init
        Stanza = escalus:wait_for_stanza(Alice),
        count_rooms(Stanza, 1),
        has_room(room_address(<<"alicesroom">>), Stanza),
        escalus:assert(is_stanza_from, [?MUC_HOST], Stanza)
    end).

disco_info(Config) ->
    escalus:story(Config, [1], fun(Alice) ->
        escalus:send(Alice, stanza_to_room(escalus_stanza:iq_get(?NS_DISCO_INFO,[]), <<"alicesroom">>)),
        Stanza = escalus:wait_for_stanza(Alice),
        escalus:assert(is_iq_result, Stanza),
        has_feature(Stanza, <<"muc_persistent">>)
    end).

disco_items(Config) ->
    escalus:story(Config, [1,1], fun(Alice, Bob) ->
        escalus:send(Alice, stanza_join_room(<<"alicesroom">>, <<"nicenick">>)),
        _Stanza = escalus:wait_for_stanza(Alice),

        escalus:send(Bob, stanza_to_room(escalus_stanza:iq_get(?NS_DISCO_ITEMS,[]), <<"alicesroom">>)),
        Stanza2 = escalus:wait_for_stanza(Bob),
        escalus:assert(is_iq_result, Stanza2)
    end).

create_and_destroy_room(Config) ->
    escalus:story(Config, [1], fun(Alice) ->
        Room1 = stanza_enter_room(<<"room1">>, <<"nick1">>),
        escalus:send(Alice, Room1),
        %Alice gets topic message after creating the room
        [S, _S2] = escalus:wait_for_stanzas(Alice, 2),
        was_room_created(S),

        DestroyRoom1 = stanza_destroy_room(<<"room1">>),
        escalus:send(Alice, DestroyRoom1),
        [Presence, Iq] = escalus:wait_for_stanzas(Alice, 2),
        was_room_destroyed(Iq),
        was_destroy_presented(Presence)
    end).

%% FAILS!
%% Example 152. Service Informs User of Inability to Create a Room
%% As of writing this testcase (2012-07-24) it fails. Room is not created
%% as expected, but the returned error message is not the one specified by XEP.
%% ejabberd returns 'forbidden' while it ought to return 'not-allowed'.
room_creation_not_allowed(Config) ->
    escalus:story(Config, [1], fun(Alice) ->
        escalus_ejabberd:with_global_option({access,muc_create,global},
                                            [{deny,all}], fun() ->

            escalus:send(Alice, stanza_enter_room(<<"room1">>, <<"nick1">>)),
            escalus:assert(is_error, [<<"cancel">>, <<"not-allowed">>],
                           escalus:wait_for_stanza(Alice))

        end)
    end).

%%  Fails.
cant_enter_locked_room(Config) ->
    escalus:story(Config, [1,1], fun(Alice, Bob) ->

        %% Create the room (should be locked on creation)
        escalus:send(Alice, stanza_muc_enter_room(<<"room1">>,
                                                  <<"alice-the-owner">>)),
        was_room_created(escalus:wait_for_stanza(Alice)),

        %% Bob should not be able to join the room
        escalus:send(Bob, stanza_enter_room(<<"room1">>, <<"just-bob">>)),
        R = escalus:wait_for_stanza(Bob),
        %% error_logger:info_msg("R:~n~p~n", [R]),
        %% sometime the predicate itself should be moved to escalus
        escalus:assert(fun ?MODULE:is_room_locked/1, R)

        end).

%% Example 155. Owner Requests Instant Room
create_instant_room(Config) ->
    escalus:story(Config, [1,1], fun(Alice, Bob) ->

        %% Create the room (should be locked on creation)
        escalus:send(Alice, stanza_muc_enter_room(<<"room1">>,
                                                  <<"alice-the-owner">>)),
        was_room_created(escalus:wait_for_stanza(Alice)),

        escalus:wait_for_stanza(Alice),
        R = escalus_stanza:setattr(stanza_instant_room(<<"room1@muc.localhost">>),
                                   <<"from">>, escalus_utils:get_jid(Alice)),
        escalus:send(Alice, R),
        escalus:assert(is_iq_result, escalus:wait_for_stanza(Alice)),

        %% Bob should be able to join the room
        escalus:send(Bob, stanza_muc_enter_room(<<"room1">>, <<"bob">>)),

        Preds = [fun(Stanza) -> escalus_pred:is_presence(Stanza) andalso
            escalus_pred:is_stanza_from(<<"room1@muc.localhost/bob">>, Stanza)
        end,
        fun(Stanza) -> escalus_pred:is_presence(Stanza) andalso
            escalus_pred:is_stanza_from(<<"room1@muc.localhost/alice-the-owner">>, Stanza)
        end],
        escalus:assert_many(Preds, escalus:wait_for_stanzas(Bob, 2))

    end).

%%  Example 156
create_reserved_room(Config) ->
    escalus:story(Config, [1], fun(Alice) ->
        %% Create the room (should be locked on creation)
        escalus:send(Alice, stanza_muc_enter_room(<<"room2">>,
                                                  <<"alice-the-owner">>)),
        was_room_created(escalus:wait_for_stanza(Alice)),
        escalus:wait_for_stanza(Alice),

        R = escalus_stanza:setattr(stanza_reserved_room(<<"room2@muc.localhost">>),
                                   <<"from">>, escalus_utils:get_jid(Alice)),
        escalus:send(Alice, R),
        S = escalus:wait_for_stanza(Alice),
        escalus:assert(is_iq_result, S),
        true = is_form(S)

    end).

%%  Examples 172-180
owner_grant_revoke(Config) ->
    escalus:story(Config, [1,1,1], fun(Alice, Bob, Kate) ->
        %% Alice joins room
        escalus:send(Alice, stanza_muc_enter_room(?config(room, Config), <<"alice">>)),
        escalus:wait_for_stanzas(Alice, 2),
        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 3),
        %% Kate joins room
        escalus:send(Kate, stanza_muc_enter_room(?config(room, Config), <<"kate">>)),
        escalus:wait_for_stanzas(Kate, 4),
        %% Skip Kate's presence
        escalus:wait_for_stanza(Bob),
        %% Skip Kate's and Bob's presences
        escalus:wait_for_stanzas(Alice, 3),

        %% Grant bob owner status
        escalus:send(Alice, stanza_set_affiliations(
            ?config(room, Config),
                [{escalus_utils:get_short_jid(Bob),<<"owner">>}])),
        escalus:assert_many([is_iq_result, is_presence], escalus:wait_for_stanzas(Alice, 2)),

        %% Bob receives his notice
        Bobs = escalus:wait_for_stanza(Bob),
        true = is_presence_with_affiliation(Bobs, <<"owner">>),
        escalus:assert(is_stanza_from,
          [room_address(?config(room, Config), <<"bob">>)], Bobs),

        %% Kate receives Bob's notice
        Kates = escalus:wait_for_stanza(Kate),
        true = is_presence_with_affiliation(Kates, <<"owner">>),
        escalus:assert(is_stanza_from,
            [room_address(?config(room, Config), <<"bob">>)], Kates),

        %% Revoke alice owner status
        Pred = fun(Stanza) ->
                escalus_pred:is_stanza_from(
                  room_address(?config(room, Config), <<"alice">>),Stanza) andalso
                is_presence_with_affiliation(Stanza, <<"admin">>)
        end,

        escalus:send(Bob, stanza_set_affiliations(
            ?config(room, Config),
                [{escalus_utils:get_short_jid(Alice), <<"admin">>}])),
        escalus:assert_many([is_iq_result, Pred], escalus:wait_for_stanzas(Bob, 2)),

        %% Alice receives her loss of ownership presence
        Alices = escalus:wait_for_stanza(Alice),
        true = is_presence_with_affiliation(Alices, <<"admin">>),
        escalus:assert(is_stanza_from,
            [room_address(?config(room,Config), <<"alice">>)], Alices),

        %% Kate receives Alice's loss of ownership presence
        Kates2 = escalus:wait_for_stanza(Kate),
        true = is_presence_with_affiliation(Kates2, <<"admin">>),
        escalus:assert(is_stanza_from,
            [room_address(?config(room,Config), <<"alice">>)], Kates2)

    end).

%%  Examples 181-185
%%  Behaves strange when we try to revoke the only owner together with
%%  granting someone else
owner_list(Config) ->
    escalus:story(Config, [1,1,1], fun(Alice, Bob, Kate) ->
        %% Alice joins room
        escalus:send(Alice, stanza_muc_enter_room(?config(room, Config), <<"alice">>)),
        escalus:wait_for_stanzas(Alice, 2),
        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 3),
        %% Kate joins room
        escalus:send(Kate, stanza_muc_enter_room(?config(room, Config), <<"kate">>)),
        escalus:wait_for_stanzas(Kate, 4),
        %% Skip Kate's presence
        escalus:wait_for_stanza(Bob),
        %% Skip Kate's and Bob's presences
        escalus:wait_for_stanzas(Alice, 3),

        %% Alice requests owner list
        escalus:send(Alice, stanza_affiliation_list_request(
            ?config(room, Config), <<"owner">>)),
        List = escalus:wait_for_stanza(Alice),

        %% Alice should be on it
        escalus:assert(is_iq_result, List),
        true = is_iq_with_affiliation(List, <<"owner">>),
        true = is_iq_with_short_jid(List, Alice),

        %% Grant Bob and Kate owners status
        escalus:send(Alice, stanza_set_affiliations(
            ?config(room, Config),
                [{escalus_utils:get_short_jid(Kate),<<"owner">>},
                 {escalus_utils:get_short_jid(Bob), <<"owner">>}])),
        escalus:assert_many([is_iq_result, is_presence, is_presence],
            escalus:wait_for_stanzas(Alice, 3)),

        %% Bob receives his and Kate's notice
        Preds = [fun(Stanza) ->
            is_presence_with_affiliation(Stanza, <<"owner">>) andalso
            escalus_pred:is_stanza_from(
                room_address(?config(room, Config), <<"bob">>), Stanza)
        end,
        fun(Stanza) ->
            is_presence_with_affiliation(Stanza, <<"owner">>) andalso
            escalus_pred:is_stanza_from(
                room_address(?config(room, Config), <<"kate">>), Stanza)
        end],
        escalus:assert_many(Preds, escalus:wait_for_stanzas(Bob, 2)),

        %% Kate receives her and Bob's notice
        escalus:assert_many(Preds, escalus:wait_for_stanzas(Kate, 2))
    end).

%%  Example 184
%%  This test fails, ejabberd returns cancel/not-allowed error while it should
%%  return auth/forbidden according to XEP
owner_unauthorized(Config) ->
    escalus:story(Config, [1,1], fun(_Alice, Bob) ->
        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 2),

        %% Bob tries to modify owner list
        escalus:send(Bob, stanza_set_affiliations(
            ?config(room, Config),
            [{escalus_utils:get_short_jid(Bob), <<"owner">>}])),
        Error = escalus:wait_for_stanza(Bob),
        error_logger:info_msg("~p~n",[Error]),
        %% Should get an error
        escalus:assert(is_error, [<<"auth">>, <<"forbidden">>],
            Error)

    end).

%%  Examples 186-195
admin_grant_revoke(Config) ->
    escalus:story(Config, [1,1,1], fun(Alice, Bob, Kate) ->
        %% Alice joins room
        escalus:send(Alice, stanza_muc_enter_room(?config(room, Config), <<"alice">>)),
        escalus:wait_for_stanzas(Alice, 2),
        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 3),
        %% Kate joins room
        escalus:send(Kate, stanza_muc_enter_room(?config(room, Config), <<"kate">>)),
        escalus:wait_for_stanzas(Kate, 4),
        %% Skip Kate's presence
        escalus:wait_for_stanza(Bob),
        %% Skip Kate's and Bob's presences
        escalus:wait_for_stanzas(Alice, 3),

        %% Grant bob owner status
        escalus:send(Alice, stanza_set_affiliations(
            ?config(room, Config),
                [{escalus_utils:get_short_jid(Bob),<<"admin">>}])),
        escalus:assert_many([is_iq_result, is_presence], escalus:wait_for_stanzas(Alice, 2)),

        %% Bob receives his notice
        Bobs = escalus:wait_for_stanza(Bob),
        true = is_presence_with_affiliation(Bobs, <<"admin">>),
        escalus:assert(is_stanza_from,
          [room_address(?config(room, Config), <<"bob">>)], Bobs),

        %% Kate receives Bob's notice
        Kates = escalus:wait_for_stanza(Kate),
        true = is_presence_with_affiliation(Kates, <<"admin">>),
        escalus:assert(is_stanza_from,
            [room_address(?config(room, Config), <<"bob">>)], Kates),

        %% Revoke Bob admin status
        Pred = fun(Stanza) ->
                escalus_pred:is_stanza_from(
                  room_address(?config(room, Config), <<"bob">>),Stanza) andalso
                is_presence_with_affiliation(Stanza, <<"none">>)
        end,

        escalus:send(Alice, stanza_set_affiliations(
            ?config(room, Config),
                [{escalus_utils:get_short_jid(Bob), <<"none">>}])),
        escalus:assert_many([is_iq_result, Pred], escalus:wait_for_stanzas(Alice, 2)),

        %% Bob receives his loss of admin presence
        Bobs2 = escalus:wait_for_stanza(Bob),
        true = is_presence_with_affiliation(Bobs2, <<"none">>),
        escalus:assert(is_stanza_from,
            [room_address(?config(room,Config), <<"bob">>)], Bobs2),

        %% Kate receives Bob's loss of admin presence
        Kates2 = escalus:wait_for_stanza(Kate),
        true = is_presence_with_affiliation(Kates2, <<"none">>),
        escalus:assert(is_stanza_from,
            [room_address(?config(room,Config), <<"bob">>)], Kates2)

    end).

%%  Examples 196-200
admin_list(Config) ->
    escalus:story(Config, [1,1,1], fun(Alice, Bob, Kate) ->
        %% Alice joins room
        escalus:send(Alice, stanza_muc_enter_room(?config(room, Config), <<"alice">>)),
        escalus:wait_for_stanzas(Alice, 2),
        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 3),
        %% Kate joins room
        escalus:send(Kate, stanza_muc_enter_room(?config(room, Config), <<"kate">>)),
        escalus:wait_for_stanzas(Kate, 4),
        %% Skip Kate's presence
        escalus:wait_for_stanza(Bob),
        %% Skip Kate's and Bob's presences
        escalus:wait_for_stanzas(Alice, 3),

        %% Alice requests owner list
        escalus:send(Alice, stanza_affiliation_list_request(
            ?config(room, Config), <<"admin">>)),
        List = escalus:wait_for_stanza(Alice),
        %% Noone should be on it
        [] = List#xmlelement.body,

        %% Grant Bob and Kate admins status
        escalus:send(Alice, stanza_set_affiliations(
            ?config(room, Config),
                [{escalus_utils:get_short_jid(Kate),<<"admin">>},
                 {escalus_utils:get_short_jid(Bob), <<"admin">>}])),
        escalus:assert_many([is_iq_result, is_presence, is_presence],
            escalus:wait_for_stanzas(Alice, 3)),

        %% Bob receives his and Kate's notice
        Preds = [fun(Stanza) ->
            is_presence_with_affiliation(Stanza, <<"admin">>) andalso
            escalus_pred:is_stanza_from(
                room_address(?config(room, Config), <<"bob">>), Stanza)
        end,
        fun(Stanza) ->
            is_presence_with_affiliation(Stanza, <<"admin">>) andalso
            escalus_pred:is_stanza_from(
                room_address(?config(room, Config), <<"kate">>), Stanza)
        end],
        escalus:assert_many(Preds, escalus:wait_for_stanzas(Bob, 2)),

        %% Kate receives her and Bob's notice
        escalus:assert_many(Preds, escalus:wait_for_stanzas(Kate, 2))
    end).

%%  Example 199
%%  This test fails, ejabberd returns cancel/not-allowed error while it should
%%  return auth/forbidden according to XEP
admin_unauthorized(Config) ->
    escalus:story(Config, [1,1], fun(_Alice, Bob) ->
        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 2),

        %% Bob tries to modify admin list
        escalus:send(Bob, stanza_set_affiliations(
            ?config(room, Config),
            [{escalus_utils:get_short_jid(Bob), <<"admin">>}])),
        Error = escalus:wait_for_stanza(Bob),
        error_logger:info_msg("~p~n",[Error]),
        %% Should get an error
        escalus:assert(is_error, [<<"auth">>, <<"forbidden">>],
            Error)

    end).

%%  Examples 201-203
destroy(Config) ->
    escalus:story(Config, [1,1], fun(Alice, Bob) ->
        %% Run disco, we should have 1 room
        escalus:send(Alice, stanza_get_rooms()),
        count_rooms(escalus:wait_for_stanza(Alice),1),

        %% Bob joins room
        escalus:send(Bob, stanza_muc_enter_room(?config(room, Config), <<"bob">>)),
        escalus:wait_for_stanzas(Bob, 2),

        %% Alice requests room destruction
        escalus:send(Alice, stanza_destroy_room(?config(room, Config))),

        %% Alice gets confirmation
        escalus:assert(is_iq_result, escalus:wait_for_stanza(Alice)),

        %% Bob gets unavailable presence
        Presence = escalus:wait_for_stanza(Bob),
        escalus:assert(is_presence_with_type, [<<"unavailable">>], Presence),
        escalus:assert(is_stanza_from,
          [room_address(?config(room, Config), <<"bob">>)], Presence),


        %% Run disco again, we should have no rooms
        escalus:send(Alice, stanza_get_rooms()),
        count_rooms(escalus:wait_for_stanza(Alice),0)
    end).

%%  Example 204
%%  This test fails
%%  Ejabberd should return auth/forbidden error whle it returns forbidden error without a type attribute
destroy_unauthorized(Config) ->
    escalus:story(Config, [1,1], fun(Alice, Bob) ->
        %% Run disco, we should have 1 room
        escalus:send(Alice, stanza_get_rooms()),
        count_rooms(escalus:wait_for_stanza(Alice),1),

        %% Bob tries to destroy Alice's room
        escalus:send(Bob, stanza_destroy_room(?config(room, Config))),

        %% Bob gets an error
        Error = escalus:wait_for_stanza(Bob),
        error_logger:info_msg("~p~n", [Error]),
        escalus:assert(is_stanza_from, [room_address(?config(room, Config))], Error),
        escalus:assert(is_error, [<<"auth">>, <<"forbidden">>], Error),

        %% Run disco again, we still should have 1 room
        escalus:send(Alice, stanza_get_rooms()),
        count_rooms(escalus:wait_for_stanza(Alice),1)
    end).
%%--------------------------------------------------------------------
%% Helpers
%%--------------------------------------------------------------------
is_message_correct(Room, SenderNick, Text, ReceivedMessage) ->
    error_logger:info_msg("tested message: ~n~p~n", [ReceivedMessage]),
    escalus_pred:is_message(ReceivedMessage),
    From = room_address(Room, SenderNick),
    From  = exml_query:attr(ReceivedMessage, <<"from">>),
    <<"groupchat">>  = exml_query:attr(ReceivedMessage, <<"type">>),
    Body = #xmlelement{name = <<"body">>, body = [#xmlcdata{content=Text}]},
    Body = exml_query:subelement(ReceivedMessage, <<"body">>).

print_next_message(User) ->
    error_logger:info_msg("~p messaege, ~n~p~n", [User, escalus:wait_for_stanza(User)]).

print(Element) ->
    error_logger:info_msg("~n~p~n", [Element]).

generate_rpc_jid({_,User}) ->
    {username, Username} = lists:keyfind(username, 1, User),
    {server, Server} = lists:keyfind(server, 1, User),
    JID = <<Username/binary, "@", Server/binary, "/rpc">>,
    {jid, JID, Username, Server, <<"rpc">>}.

%Groupchat 1.0 protocol
stanza_groupchat_enter_room(Room, Nick) ->
    stanza_to_room(escalus_stanza:presence(<<"available">>), Room, Nick).


stanza_groupchat_enter_room_no_nick(Room) ->
    stanza_to_room(escalus_stanza:presence(<<"available">>), Room).


%Basic MUC protocol
stanza_muc_enter_room(Room, Nick) ->
    stanza_to_room(
        escalus_stanza:presence(  <<"available">>,
                                [#xmlelement{ name = <<"x">>, attrs=[{<<"xmlns">>, <<"http://jabber.org/protocol/muc">>}]}]),
        Room, Nick).

stanza_muc_enter_password_protected_room(Room, Nick, Password) ->
    stanza_to_room(
        escalus_stanza:presence(  <<"available">>,
                                [#xmlelement{ name = <<"x">>, attrs=[{<<"xmlns">>, <<"http://jabber.org/protocol/muc">>}],
                                             body=[#xmlelement{name = <<"password">>, body = [#xmlcdata{content=[Password]}]} ]}]),
        Room, Nick).


start_room(Config, User, Room, Nick, Opts) ->
    From = generate_rpc_jid(User),
    escalus_ejabberd:rpc(mod_muc, create_room,
        [<<"localhost">>, Room, From, Nick, Opts]),
    [{nick, Nick}, {room, Room} | Config].

destroy_room(Config) ->
    case escalus_ejabberd:rpc(ets, lookup, [muc_online_room,
        {?config(room, Config), <<"muc.localhost">>}]) of
        [{_,_,Pid}|_] -> gen_fsm:send_all_state_event(Pid, destroy);
        _ -> ok
    end.

room_address(Room) ->
    <<Room/binary, "@", ?MUC_HOST/binary>>.

room_address(Room, Nick) ->
    <<Room/binary, "@", ?MUC_HOST/binary, "/", Nick/binary>>.

%%--------------------------------------------------------------------
%% Helpers (stanzas)
%%--------------------------------------------------------------------

stanza_message_to_room(Room, Payload) ->
    stanza_to_room(#xmlelement{name = <<"message">>, body = Payload}, Room).

stanza_room_subject(Room, Subject) ->
    stanza_to_room(#xmlelement{name = <<"message">>,
        attrs = [{<<"type">>,<<"groupchat">>}],
        body = [#xmlelement{
            name = <<"subject">>,
            body = [exml:escape_cdata(Subject)]
        }]
    }, Room).

stanza_mediated_invitation(Room, Invited) ->
    Payload = [ #xmlelement{name = <<"invite">>,
        attrs = [{<<"to">>, escalus_utils:get_short_jid(Invited)}]} ],
    stanza_to_room(#xmlelement{name = <<"message">>,
        body = [ #xmlelement{
            name = <<"x">>,
            attrs = [{<<"xmlns">>, ?NS_MUC_USER}],
            body = Payload }
        ]}, Room).

stanza_set_roles(Room, List) ->
    Payload = [ #xmlelement{name = <<"item">>,
        attrs = [{<<"nick">>, Nick}, {<<"role">>, Role}]} || {Nick,Role} <- List ],
    stanza_to_room(escalus_stanza:iq_set(?NS_MUC_ADMIN, Payload), Room).

stanza_set_affiliations(Room, List) ->
    Payload = [ #xmlelement{name = <<"item">>,
        attrs = [{<<"jid">>, JID}, {<<"affiliation">>, Affiliation}]}
            || {JID,Affiliation} <- List ],
    stanza_to_room(escalus_stanza:iq_set(?NS_MUC_ADMIN, Payload), Room).

stanza_role_list_request(Room, Role) ->
    Payload = [ #xmlelement{name = <<"item">>,
        attrs = [{<<"role">>, Role}]} ],
    stanza_to_room(escalus_stanza:iq_get(?NS_MUC_ADMIN, Payload), Room).

stanza_affiliation_list_request(Room, Affiliation) ->
    Payload = [ #xmlelement{name = <<"item">>,
        attrs = [{<<"affiliation">>, Affiliation}]} ],
    stanza_to_room(escalus_stanza:iq_get(?NS_MUC_ADMIN, Payload), Room).

stanza_admin_list(Room, Items) ->
    Payload = [ #xmlelement{name = <<"item">>,
                            attrs = [{<<"affiliation">>, Affiliation},
                                     {<<"jid">>, JID}]}
              || {Affiliation, JID} <- Items ],
    stanza_to_room(escalus_stanza:iq_set(?NS_MUC_ADMIN, Payload), Room).

stanza_ban_list_request(Room) ->
    Payload = #xmlelement{name = <<"item">>,
        attrs = [{<<"affiliation">>, <<"outcast">>}]},
    stanza_to_room(escalus_stanza:iq_get(?NS_MUC_ADMIN, Payload), Room).

stanza_ban_user(User, Room) ->
  stanza_to_room(escalus_stanza:iq_set(?NS_MUC_ADMIN, #xmlelement{
      name = <<"item">>,
      attrs = [{<<"affiliation">>,<<"outcast">>},
               {<<"jid">>, escalus_utils:get_short_jid(User)}]
      }), Room).

stanza_join_room(Room, Nick) ->
    stanza_to_room(#xmlelement{name = <<"presence">>, body =
        #xmlelement{
            name = <<"x">>,
            attrs = [{<<"xmlns">>,<<"http://jabber.org/protocol/muc">>}]
        }
    },Room, Nick).

stanza_voice_request_form(Room) ->
    Payload = [ form_field({<<"muc#role">>, <<"participant">>, <<"text-single">>}) ],
    stanza_message_to_room(Room, stanza_form(Payload, ?NS_MUC_REQUEST)).

stanza_configuration_form(Room, Params) ->
    DefaultParams = [],
    FinalParams = lists:foldl(
        fun({Key,_Val,_Type},Acc) ->
            lists:keydelete(Key,1,Acc)
        end,
        DefaultParams, Params) ++ Params,
    Payload = [ form_field(FieldData) || FieldData <- FinalParams ],
    stanza_to_room(escalus_stanza:iq_set(
          ?NS_MUC_OWNER, stanza_form(Payload, ?NS_MUC_ROOMCONFIG)), Room).

stanza_form(Payload, Type) ->
    #xmlelement{
        name = <<"x">>,
        attrs = [{<<"xmlns">>,<<"jabber:x:data">>}, {<<"type">>,<<"submit">>}],
        body = [form_field({<<"FORM_TYPE">>, Type, <<"hidden">>}) | Payload]
    }.

form_field({Var, Value, Type}) ->
    #xmlelement{ name  = <<"field">>,
                 attrs = [{<<"type">>, Type},{<<"var">>, Var}],
                 body  = [#xmlelement{ name = <<"value">>,
                                       body = [#xmlcdata{content = Value}] }] }.

stanza_instant_room(Room) ->
    X = #xmlelement{name = <<"x">>, attrs = [{<<"xmlns">>, ?NS_DATA_FORMS},
                                             {<<"type">>, <<"submit">>}]},
    escalus_stanza:to(escalus_stanza:iq_set(?NS_MUC_OWNER, [X]), Room).

stanza_reserved_room(Room) ->
    escalus_stanza:to(escalus_stanza:iq_get(?NS_MUC_OWNER, []), Room).

stanza_destroy_room(Room) ->
    Payload = [ #xmlelement{name = <<"destroy">>} ],
    stanza_to_room(escalus_stanza:iq_set(?NS_MUC_OWNER, Payload), Room).

stanza_enter_room(Room, Nick) ->
    stanza_to_room(#xmlelement{name = <<"presence">>}, Room, Nick).

stanza_to_room(Stanza, Room, Nick) ->
    escalus_stanza:to(Stanza, room_address(Room, Nick)).

stanza_to_room(Stanza, Room) ->
    escalus_stanza:to(Stanza, room_address(Room)).

stanza_get_rooms() ->
    %% <iq from='hag66@shakespeare.lit/pda'
    %%   id='zb8q41f4'
    %%   to='chat.shakespeare.lit'
    %%   type='get'>
    %% <query xmlns='http://jabber.org/protocol/disco#items'/>
    %% </iq>
    escalus_stanza:setattr(escalus_stanza:iq_get(?NS_DISCO_ITEMS, []), <<"to">>,
        ?MUC_HOST).

stanza_get_features() ->
    %% <iq from='hag66@shakespeare.lit/pda'
    %%     id='lx09df27'
    %%     to='chat.shakespeare.lit'
    %%     type='get'>
    %%  <query xmlns='http://jabber.org/protocol/disco#info'/>
    %% </iq>
    escalus_stanza:setattr(escalus_stanza:iq_get(?NS_DISCO_INFO, []), <<"to">>,
        ?MUC_HOST).

stanza_get_services(Config) ->
    %% <iq from='hag66@shakespeare.lit/pda'
    %%     id='h7ns81g'
    %%     to='shakespeare.lit'
    %%     type='get'>
    %%   <query xmlns='http://jabber.org/protocol/disco#items'/>
    %% </iq>
    escalus_stanza:setattr(escalus_stanza:iq_get(?NS_DISCO_ITEMS, []), <<"to">>,
        escalus_config:get_config(ejabberd_domain, Config)).

%%--------------------------------------------------------------------
%% Helpers (assertions)
%%--------------------------------------------------------------------

is_form(Stanza) ->
    exml_query:path(Stanza,[{element, <<"query">>}, {element,<<"x">>},
        {attr, <<"xmlns">>}]) =:= ?NS_DATA_FORMS.

is_groupchat_message(Stanza) ->
    escalus_pred:is_message(Stanza) andalso
    escalus_pred:has_type(<<"groupchat">>, Stanza).

is_subject_message(Stanza) ->
    is_groupchat_message(Stanza) andalso
    exml_query:subelement(Stanza, <<"subject">>) /= undefined.

is_subject_message(Stanza, Subject) ->
    is_groupchat_message(Stanza) andalso
    exml_query:path(Stanza, [{element,<<"subject">>},cdata]) == Subject.

is_unavailable_presence(Stanza, Status) ->
    escalus_pred:is_presence_with_type(<<"unavailable">>,Stanza) andalso
    is_presence_with_status_code(Stanza, Status).

is_membership_presence(Stanza, Affiliation, Role) ->
    is_presence_with_affiliation(Stanza, Affiliation) andalso
    is_presence_with_role(Stanza, Role).

is_invitation(Stanza) ->
    escalus:assert(is_message, Stanza),
    #xmlelement{} = exml_query:path(Stanza, [{element, <<"x">>}, {element, <<"invite">>}]).

is_presence_with_role(Stanza, Role) ->
    is_with_role(exml_query:subelement(Stanza, <<"x">>), Role).

is_iq_with_role(Stanza, Role) ->
    is_with_role(exml_query:subelement(Stanza, <<"query">>), Role).

is_with_role(Stanza, Role) ->
    Items = exml_query:subelements(Stanza, <<"item">>),
    lists:any(fun(Item) ->
        exml_query:attr(Item, <<"role">>) =:= Role
    end, Items).

is_presence_with_nick(Stanza, Nick) ->
    escalus_pred:is_presence(Stanza) andalso
    exml_query:path(Stanza,[{element, <<"x">>},
        {element, <<"item">>}, {attribute, <<"nick">>}]) == Nick.

is_presence_with_affiliation(Stanza, Affiliation) ->
    is_affiliation(exml_query:subelement(Stanza, <<"x">>), Affiliation).

is_iq_with_affiliation(Stanza, Affiliation) ->
    is_affiliation(exml_query:subelement(Stanza, <<"query">>), Affiliation).

is_affiliation(Stanza, Affiliation) ->
    Items = exml_query:subelements(Stanza, <<"item">>),
    lists:any(fun(Item) ->
        exml_query:attr(Item, <<"affiliation">>) =:= Affiliation
    end, Items).

is_presence_with_jid(Stanza, User) ->
    is_jid(exml_query:subelement(Stanza, <<"x">>), User).

is_iq_with_jid(Stanza, User) ->
    is_jid(exml_query:subelement(Stanza, <<"query">>), User).

is_jid(Stanza, User) ->
    Items = exml_query:subelements(Stanza, <<"item">>),
    JID = escalus_utils:get_jid(User),
    lists:any(fun(Item) -> exml_query:attr(Item, <<"jid">>) =:= JID end, Items).

is_presence_with_short_jid(Stanza, User) ->
    is_short_jid(exml_query:subelement(Stanza, <<"x">>), User).

is_iq_with_short_jid(Stanza, User) ->
    is_short_jid(exml_query:subelement(Stanza, <<"query">>), User).

is_short_jid(Stanza, User) ->
    Items = exml_query:subelements(Stanza, <<"item">>),
    JID = escalus_utils:get_short_jid(User),
    lists:any(fun(Item) -> exml_query:attr(Item, <<"jid">>) =:= JID end, Items).

is_presence_with_status_code(Presence, Code) ->
    escalus:assert(is_presence, Presence),
    Code == exml_query:path(Presence, [{element, <<"x">>}, {element, <<"status">>},
        {attr, <<"code">>}]).

has_feature(Stanza, Feature) ->
    Features = exml_query:path(Stanza, [{element, <<"query">>}, {elements, <<"feature">>}]),
    true = lists:any(fun(Item) ->
                        exml_query:attr(Item, <<"var">>) == Feature
                     end,
                     Features).

was_destroy_presented(#xmlelement{body = [Items]} = Presence) ->
    #xmlelement{} = exml_query:subelement(Items, <<"destroy">>),
    <<"unavailable">> = exml_query:attr(Presence, <<"type">>).

was_room_destroyed(Query) ->
    <<"result">> = exml_query:attr(Query, <<"type">>).

was_room_created(#xmlelement{body = [X]}) ->
    <<"201">> = exml_query:path(X, [{element, <<"status">>},
                                    {attr, <<"code">>}]),
    <<"owner">> = exml_query:path(X, [{element, <<"item">>},
                                      {attr, <<"affiliation">>}]),
    <<"moderator">> = exml_query:path(X, [{element, <<"item">>},
                                          {attr, <<"role">>}]).

has_room(JID, #xmlelement{body = [ #xmlelement{body = Rooms} ]}) ->
    %% <iq from='chat.shakespeare.lit'
    %%   id='zb8q41f4'
    %%   to='hag66@shakespeare.lit/pda'
    %%   type='result'>
    %% <query xmlns='http://jabber.org/protocol/disco#items'>
    %%    <item jid='heath@chat.shakespeare.lit'
    %%         name='A Lonely Heath'/>
    %%    <item jid='coven@chat.shakespeare.lit'
    %%         name='A Dark Cave'/>
    %%    <item jid='forres@chat.shakespeare.lit'
    %%         name='The Palace'/>
    %%     <item jid='inverness@chat.shakespeare.lit'
    %%         name='Macbeth&apos;s Castle'/>
    %%   </query>
    %% </iq>

    RoomPred = fun(Item) ->
        exml_query:attr(Item, <<"jid">>) == JID
    end,
    true = lists:any(RoomPred, Rooms).

count_rooms(#xmlelement{body = [ #xmlelement{body = Rooms} ]}, N) ->
    N = length(Rooms).

has_features(#xmlelement{body = [ Query ]}) ->
    %%<iq from='chat.shakespeare.lit'
    %%  id='lx09df27'
    %%  to='hag66@shakespeare.lit/pda'
    %%  type='result'>
    %%  <query xmlns='http://jabber.org/protocol/disco#info'>
    %%    <identity
    %%      category='conference'
    %%      name='Shakespearean Chat Service'
    %%      type='text'/>
    %%      <feature var='http://jabber.org/protocol/muc'/>
    %%  </query>
    %%</iq>

    Identity = exml_query:subelement(Query, <<"identity">>),
    <<"conference">> = exml_query:attr(Identity, <<"category">>),
    #xmlelement{name = _Name, attrs = _Attrs, body = _Body} = exml_query:subelement(Query, <<"feature">>).

has_muc(#xmlelement{body = [ #xmlelement{body = Services} ]}) ->
    %% should be along the lines of (taken straight from the XEP):
    %% <iq from='shakespeare.lit'
    %%     id='h7ns81g'
    %%     to='hag66@shakespeare.lit/pda'
    %%     type='result'>
    %%   <query xmlns='http://jabber.org/protocol/disco#items'>
    %%     <item jid='chat.shakespeare.lit'
    %%           name='Chatroom Service'/>
    %%   </query>
    %% </iq>

    %% is like this:
    %% {xmlelement,<<"iq">>,
    %%     [{<<"from">>,<<"localhost">>},
    %%         {<<"to">>,<<"alice@localhost/res1">>},
    %%         {<<"id">>,<<"a5eb1dc70826598893b15f1936b18a34">>},
    %%         {<<"type">>,<<"result">>}],
    %%     [{xmlelement,<<"query">>,
    %%             [{<<"xmlns">>,
    %%                     <<"http://jabber.org/protocol/disco#items">>}],
    %%             [{xmlelement,<<"item">>,
    %%                     [{<<"jid">>,<<"vjud.localhost">>}],
    %%                     []},
    %%                 {xmlelement,<<"item">>,
    %%                     [{<<"jid">>,<<"pubsub.localhost">>}],
    %%                     []},
    %%                 {xmlelement,<<"item">>,
    %%                     [{<<"jid">>,<<"muc.localhost">>}],
    %%                     []},
    %%                 {xmlelement,<<"item">>,
    %%                     [{<<"jid">>,<<"irc.localhost">>}],
    %%                     []}]}]}
    %% how to obtaing output like the above? simply put this in the test case:
    %% S = escalus:wait_for_stanza(Alice),
    %% error_logger:info_msg("~p~n", [S]),
    IsMUC = fun(Item) ->
        exml_query:attr(Item, <<"jid">>) == ?MUC_HOST
    end,
    lists:any(IsMUC, Services).

is_room_locked(Stanza) ->
    escalus_pred:is_presence(Stanza)
    andalso
    escalus_pred:is_error(<<"cancel">>, <<"item-not-found">>, Stanza).
