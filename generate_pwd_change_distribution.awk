##############################################################################################################################
#
# Purpose: Outputs an account password change schedule with the following constraints:
# - If possible within the max_changes_per_day constraint, no account password will expire
# - Minimize the number of passwords that are changed on any one day
#
# Input variables:
#  - reset_period (days, e.g. 365)
#  - max_changes_per_day (number, e.g. 5)
#
# Input format:
#  - Expect lines of the form:
#    <days since last change>    <account>
#  - Example input records:
#    380    ./News/Reference/nytimes.com.gpg
#    385    ./News/Reference/quora.com.gpg
#    150    ./News/Reference/wsj.com.gpg
#
# Output format:
#  - Sections beginning in a future date (represented as number of days after today),
#    followed by each account on a separate line
#  - Example output records:
#    0
#    ./News/Reference/nytimes.com.gpg
#    ./News/Reference/quora.com.gpg
#
#    150
#    ./News/Reference/wsj.com.gpg
#
# See minimize_changes_per_day() for how this schedule is achieved.
#
##############################################################################################################################

BEGIN {
    acct_changes_dictionary_init()
}

{
    change_days_ago = $1
    account = $2
    period_change_day_diff = reset_period - change_days_ago
    change_day = 0 > period_change_day_diff ? 0 : period_change_day_diff;
    acct_changes_dictionary_add(change_day, account)
}

END {
    minimize_changes_per_day();
    acct_changes_dictionary_print();
}

#
# minimize_changes_per_day()
# 
# This is a greedy algorithm that achieves the schedule specified in the opening comment.
# 
# Initialization assumptions:
#    - acct_changes_dictionary is a lookup with range 0..reset_period (where 0 is today)
#    - each entry of acct_changes_dictionary is a list of all accounts that expire that day
# 
# General Method:
#    1. Traverses each day of acct_changes_dictionary in order, distributing accounts among strictly earlier days unless:
#       a. All preceding days already have max_changes_per_day accounts
#       b. Currently visited day has about the same (within 1) number of accounts to change as all preceding days
#    2. If (a) is true, accounts will be carried over to future days and will have priority until
#       no more are carried over, at which point (1) continues.
# 
# Further notes:
#    - A min heap is maintained to keep track of openings in preceding days
#    - Filenames carried over are stored on a queue to ensure they are prioritized by expiration urgency
# 
function minimize_changes_per_day(                     i,account) {
    min_changes_heap_init();
    carried_over_accounts_init();
    for(i = 0; i < reset_period; i++) {
        while(0 < min_changes_heap_size && max_changes_per_day < acct_changes_dictionary_size_on_day(i))
            move_from_day_to_min_previous_day(i);
        
        if(max_changes_per_day < acct_changes_dictionary_size_on_day(i) || 0 < carried_over_accounts_size()) {
            while(acct_changes_dictionary_size_on_day(i) > 0) {
                account = acct_changes_dictionary_del(i);
                carried_over_accounts_enqueue(account);
            }
            while(acct_changes_dictionary_size_on_day(i) < max_changes_per_day && 0 < carried_over_accounts_size()) {
                account = carried_over_accounts_dequeue();
                acct_changes_dictionary_add(i, account);
            }
        }
        
        while(0 < min_changes_heap_size &&
              acct_changes_dictionary_size_on_day(i) > 1 + min_changes_heap_node_value(0)) {
            move_from_day_to_min_previous_day(i);
        }
        
        if(max_changes_per_day > acct_changes_dictionary_size_on_day(i))
            min_changes_heap_add(i);
    }
}

##############################################################################################################################
# acct_changes_dictionary operations
##############################################################################################################################

function acct_changes_dictionary_init(                           i) {
    for(i = 0; i < reset_period; i++)
        acct_changes_dictionary[i][0] = 0;
}

function acct_changes_dictionary_add(day, account,               num_accounts) {
    num_accounts = 1 + acct_changes_dictionary[day][0];
    acct_changes_dictionary[day][0] = num_accounts;
    acct_changes_dictionary[day][num_accounts] = account;
}

function acct_changes_dictionary_del(day,                        num_accounts) {
    num_accounts = acct_changes_dictionary[day][0];
    account_to_drop = acct_changes_dictionary[day][num_accounts];
    acct_changes_dictionary[day][0] = num_accounts - 1;
    return account_to_drop;
}

function acct_changes_dictionary_size_on_day(day) {
    return acct_changes_dictionary[day][0];
}

function acct_changes_dictionary_print(                          i,j,account) {
    for(i = 0; i < reset_period; i++) {
        if(0 < acct_changes_dictionary_size_on_day(i)) 
            printf("%s\n", i);
        for(j = 1; j <= acct_changes_dictionary_size_on_day(i); j++) {
            account = acct_changes_dictionary[i][j];
            printf("%s\n", account);
        }
        if(0 < acct_changes_dictionary_size_on_day(i)) 
            printf("\n");
    }
}

##############################################################################################################################
# min_changes_heap operations
##############################################################################################################################

function min_changes_heap_init() {
    min_changes_heap_size = 0;
}

function min_changes_heap_top() {
    return min_changes_heap[0];
}

function min_changes_heap_add(day) {
    min_changes_heap_size++;
    min_changes_heap[min_changes_heap_size - 1] = day;
    min_changes_heap_bubble_up(min_changes_heap_size - 1);
}

function min_changes_heap_del(                                   min_day) {
    if(min_changes_heap_size > 0) {
        min_day = min_changes_heap[0];
        min_changes_heap[0] = min_changes_heap[min_changes_heap_size - 1];
        min_changes_heap_size--;
        min_changes_heap_bubble_down(0);
        return min_day;
    }
}

function min_changes_heap_node_value(node) {
    return acct_changes_dictionary_size_on_day(min_changes_heap[node]);
}

function move_from_day_to_min_previous_day(day,                  min_day,account_to_move) {
    min_day = min_changes_heap_del();
    account_to_move = acct_changes_dictionary_del(day);
    acct_changes_dictionary_add(min_day, account_to_move);
    if(acct_changes_dictionary_size_on_day(min_day) < max_changes_per_day)
        min_changes_heap_add(min_day);
}

function min_changes_heap_bubble_up(node,                        parent) {
    if(node > 0) {
        parent = (node - 1) / 2;
        if(min_changes_heap_node_value(parent) > min_changes_heap_node_value(node)) {
            min_changes_heap_swap(node, parent);
            min_changes_heap_bubble_up(parent);
        }
    }
}

function min_changes_heap_swap(i,j,                              temp) {
    temp = min_changes_heap[i];
    min_changes_heap[i] = min_changes_heap[j];
    min_changes_heap[j] = temp;
}

function min_changes_heap_bubble_down(node,                      left,right) {
    left = 2 * node + 1;
    right = 2 * node + 2;
    if(left < min_changes_heap_size &&
       min_changes_heap_node_value(node) > min_changes_heap_node_value(left)) {
        min_changes_heap_swap(node, left);
        min_changes_heap_bubble_down(left);
    } else if(right < min_changes_heap_size &&
              min_changes_heap_node_value(node) > min_changes_heap_node_value(right)) {
        min_changes_heap_swap(node, right);
        min_changes_heap_bubble_down(right);
    }
}

##############################################################################################################################
# carried_over_accounts queue operations
##############################################################################################################################

function carried_over_accounts_init() {
    carried_over_accounts_head = 0;
    carried_over_accounts_tail = -1;
}

function carried_over_accounts_size() {
    return carried_over_accounts_tail - carried_over_accounts_head + 1;
}

function carried_over_accounts_enqueue(account) {
    carried_over_accounts[carried_over_accounts_tail++] = account;
}

function carried_over_accounts_dequeue() {
    if(carried_over_accounts_size() > 0) {
        return carried_over_accounts[carried_over_accounts_head++];
    }
}
