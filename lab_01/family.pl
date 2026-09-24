% ============================================
% Минимальная программа для проверки среды
% SWI-Prolog
% --------------------------------------------
% Практическая работа №1, «Стили и методы
% программирования. Часть 2».
% Предметная область: родственные отношения.
%
% Загрузка:  swipl family.pl
%       или  ?- [family].
% ============================================

% --- Факты: родительские отношения ---
% parent(X, Y): X является родителем Y.
parent(tom, bob).
parent(tom, liz).
parent(bob, ann).
parent(bob, pat).
parent(pat, jim).

% --- Факты: пол ---
male(tom).
male(bob).
male(pat).
male(jim).
female(liz).
female(ann).

% --- Правила ---
% father(X, Y): X — отец Y, если X — родитель Y и X — мужчина.
father(X, Y) :- parent(X, Y), male(X).

% mother(X, Y): X — мать Y, если X — родитель Y и X — женщина.
mother(X, Y) :- parent(X, Y), female(X).

% grandparent(X, Z): X — дед/бабушка Z, если существует Y,
% такой что X — родитель Y, а Y — родитель Z.
grandparent(X, Z) :- parent(X, Y), parent(Y, Z).

% ancestor(X, Y): X — предок Y.
% Базовый случай: родитель является предком.
ancestor(X, Y) :- parent(X, Y).
% Рекурсивный случай: предок родителя является предком.
ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y).
