% ============================================
% Динамическая база фактов об отношении «больше»
% SWI-Prolog
% --------------------------------------------
% Практическая работа №2, задание 2, «Стили и
% методы программирования. Часть 2».
%
% Пользователь вводит с консоли отношения вида
%     яблоко > слива        (яблоко больше сливы)
%     вишня < слива         (вишня меньше сливы)
% до символа остановки '#'. Факты запоминаются в
% динамической базе, после чего программа выводит
% самый большой и самый маленький объект.
%
% Загрузка:  swipl compare.pl
% Запуск:    ?- start.
% ============================================

% --- Динамическая база фактов ---
% bigger(X, Y): X больше Y (введённые пользователем факты).
% object(X):    X встретился во вводе (порядок сохраняется).
:- dynamic bigger/2.
:- dynamic object/1.

% Символ, которым завершается ввод.
stop_symbol('#').

% --- Правила вывода ---
% greater(X, Y): X больше Y — прямо или по цепочке (транзитивное замыкание).
% Цикл невозможен: add_relation/2 не принимает противоречивых фактов.
greater(X, Y) :- bigger(X, Y).
greater(X, Y) :- bigger(X, Z), greater(Z, Y).

% largest(X): X самый большой — ни один объект не больше X.
largest(X) :- object(X), \+ bigger(_, X).

% smallest(X): X самый маленький — X не больше ни одного объекта.
smallest(X) :- object(X), \+ bigger(X, _).

% --- Ввод с консоли ---
% start: очистить базу, считать отношения, вывести ответ.
start :-
    retractall(bigger(_, _)),
    retractall(object(_)),
    stop_symbol(Stop),
    format("Вводите отношения: «A > B» (A больше B) или «A < B» (A меньше B).~n"),
    format("Для завершения ввода введите ~w~n", [Stop]),
    prompt(Old, ''),                % убрать стандартное приглашение «|: »
    read_relations(Stop),
    prompt(_, Old),
    report.

% read_relations(+Stop): читать строки, пока не встретится символ остановки
% или конец ввода (Ctrl+D).
read_relations(Stop) :-
    format("ввод: "),
    flush_output,
    read_line_to_string(user_input, Line),
    (   Line == end_of_file
    ->  nl
    ;   normalize_space(string(Clean), Line),
        (   atom_string(Stop, Clean)
        ->  true
        ;   process_line(Clean),
            read_relations(Stop)
        )
    ).

% process_line(+Строка): разобрать строку «A знак B» и добавить факт.
process_line("") :- !.
process_line(Line) :-
    string_lower(Line, Lower),
    split_string(Lower, " ", "", [A, Sign, B]),
    sign_direction(Sign, Dir),
    !,
    atom_string(X, A),
    atom_string(Y, B),
    (   Dir == bigger
    ->  add_relation(X, Y)
    ;   add_relation(Y, X)
    ).
process_line(Line) :-
    format("  не понял «~s»: нужен формат «A > B» или «A < B»~n", [Line]).

sign_direction(">", bigger).
sign_direction("<", smaller).
sign_direction("больше", bigger).
sign_direction("меньше", smaller).

% add_relation(+X, +Y): запомнить «X больше Y», если факт не противоречит базе.
add_relation(X, X) :-
    !,
    format("  отклонено: ~w не может быть больше самого себя~n", [X]).
add_relation(X, Y) :-
    greater(X, Y),
    !,
    format("  уже известно: ~w больше ~w~n", [X, Y]).
add_relation(X, Y) :-
    greater(Y, X),
    !,
    format("  отклонено: противоречит базе (~w больше ~w)~n", [Y, X]).
add_relation(X, Y) :-
    assertz(bigger(X, Y)),
    remember(X),
    remember(Y),
    format("  принято: ~w больше ~w~n", [X, Y]).

remember(X) :- object(X), !.
remember(X) :- assertz(object(X)).

% --- Ответ на контрольный вопрос ---
report :-
    findall(X, object(X), Objects),
    findall(X, largest(X), Max),
    findall(X, smallest(X), Min),
    length(Objects, N),
    aggregate_all(count, bigger(_, _), M),
    nl,
    format("Объектов: ~d, введённых отношений: ~d~n", [N, M]),
    answer("Самый большой", Max),
    answer("Самый маленький", Min).

answer(_, []) :-
    !,
    format("Отношения не введены.~n").
answer(Title, [X]) :-
    !,
    format("~s: ~w~n", [Title, X]).
answer(Title, Xs) :-
    atomic_list_concat(Xs, ', ', List),
    format("~s: единого нет, между собой несравнимы: ~w~n", [Title, List]).
