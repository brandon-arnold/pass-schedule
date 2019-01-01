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
    if(0 > period_change_day_diff)
        change_day = 0;
    else
        change_day = period_change_day_diff;
    acct_changes_dictionary_add(change_day, account)
}

END {
    printf("\n");
    minimize_changes_per_day();
    acct_changes_dictionary_print();
}

#
# minimize_changes_per_day()
# 
# This is a greedy algorithm that achieves the schedule specified in the opening comment.
# 
# Initialization assumptions:
#    - acct_changes_dictionary is a lookup ranging from acct_changes_dictionary[0] (today) to acct_changes_dictionary[reset_period]
#    - each entry of acct_changes_dictionary contains all accounts that expire that day
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
function minimize_changes_per_day() {
    min_changes_heap_init();
    carried_over_accounts_init();
    for(i = 0; i < reset_period; i++) {
        # if day i has more than max_changes_per_day, attempt to greedily shift any accounts to previous days
        while(0 < min_changes_heap_size && max_changes_per_day < acct_changes_dictionary_size_on_day(i))
            move_from_day_to_min_previous_day(i);
        
        # if day i still has more than max_changes_per_day, or if any accounts are already being carried over from previous days
        #   then (a) give carried over accounts priority over anything in day i, and (b) add any overages from day i
        #   to the carried over account queue
        if(max_changes_per_day < acct_changes_dictionary_size_on_day(i) || 0 < carried_over_accounts_size()) {
            while(acct_changes_dictionary_size_on_day(i) > 0) {
                account_to_move = acct_changes_dictionary_del(i);
                carried_over_accounts_enqueue(account_to_move);
            }
            while(acct_changes_dictionary_size_on_day(i) < max_changes_per_day && 0 < carried_over_accounts_size()) {
                account_to_move = carried_over_accounts_dequeue();
                acct_changes_dictionary_add(i, account_to_move);
            }
        }
        
        # if day i has at least 2 more accounts than any previous day, greedily shift accounts to earlier days
        #   (note: if accounts were being carried over in the previous condition, nothing will happen here)
        while(0 < min_changes_heap_size &&
              acct_changes_dictionary_size_on_day(i) > 1 + min_changes_heap_node_value(0)) {
            move_from_day_to_min_previous_day(i);
        }
        
        # if there is headroom in day i, add it to the min changes heap
        if(max_changes_per_day > acct_changes_dictionary_size_on_day(i))
            min_changes_heap_add(i);
    }
}

##############################################################################################################################
# acct_changes_dictionary operations
##############################################################################################################################

function acct_changes_dictionary_init() {
    for(i = 0; i < reset_period; i++)
        acct_changes_dictionary[i][0] = 0;
}

function acct_changes_dictionary_add(day_to_add, account_to_add) {
    num_accounts_on_add_day = 1 + acct_changes_dictionary[day_to_add][0];
    acct_changes_dictionary[day_to_add][0] = num_accounts_on_add_day;
    acct_changes_dictionary[day_to_add][num_accounts_on_add_day] = account_to_add;
}

function acct_changes_dictionary_del(day_to_del) {
    num_accounts_on_del_day = acct_changes_dictionary[day_to_del][0];
    account_to_drop = acct_changes_dictionary[day_to_del][num_accounts_on_del_day];
    acct_changes_dictionary[day_to_del][0] = num_accounts_on_del_day - 1;
    return account_to_drop;
}

function acct_changes_dictionary_size_on_day(day) {
    return acct_changes_dictionary[day][0];
}

function acct_changes_dictionary_print() {
    for(day_to_print = 0; day_to_print < reset_period; day_to_print++) {
        if(0 < acct_changes_dictionary_size_on_day(day_to_print)) 
            printf("%s\n", day_to_print);
        for(account_on_day = 1; account_on_day <= acct_changes_dictionary_size_on_day(day_to_print); account_on_day++) {
            account_to_display = acct_changes_dictionary[day_to_print][account_on_day];
            printf("%s\n", account_to_display);
        }
        if(0 < acct_changes_dictionary_size_on_day(day_to_print)) 
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

function min_changes_heap_del() {
    if(min_changes_heap_size > 0) {
        min_day = min_changes_heap[0];
        min_changes_heap[0] = min_changes_heap[min_changes_heap_size - 1];
        min_changes_heap_size--;
        min_changes_heap_bubble_down(0);
        return min_day;
    }
}

function min_changes_heap_node_value(node_with_value) {
    return acct_changes_dictionary_size_on_day(min_changes_heap[node_with_value]);
}

function move_from_day_to_min_previous_day(day) {
    cur_min_day = min_changes_heap_del();
    account_to_move = acct_changes_dictionary_del(day);
    acct_changes_dictionary_add(cur_min_day, account_to_move);
    if(min_day_size < max_changes_per_day)
        min_changes_heap_add(cur_min_day);
}

function min_changes_heap_bubble_up(node_to_bubble) {
    if(node_to_bubble > 0) {
        parent = (node_to_bubble - 1) / 2;
        if(min_changes_heap_node_value(parent) > min_changes_heap_node_value(node_to_bubble)) {
            min_changes_heap_swap(node_to_bubble, parent);
            min_changes_heap_bubble_up(parent);
        }
    }
}

function min_changes_heap_swap(first, second) {
    temp = min_changes_heap[first];
    min_changes_heap[first] = min_changes_heap[second];
    min_changes_heap[second] = temp;
}

function min_changes_heap_bubble_down(node_to_bubble) {
    left = 2 * node_to_bubble + 1;
    right = 2 * node_to_bubble + 2;
    if(left < min_changes_heap_size && min_changes_heap_node_value(node_to_bubble) > min_changes_heap_node_value(left)) {
        min_changes_heap_swap(node_to_bubble, left);
        min_changes_heap_bubble_down(left);
    } else if(right < min_changes_heap_size && min_changes_heap_node_value(node_to_bubble) > min_changes_heap_node_value(right)) {
        min_changes_heap_swap(node_to_bubble, right);
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
    return carried_over_accounts_tail - carried_over_accounts_head;
}

function carried_over_accounts_enqueue(account) {
    carried_over_accounts[carried_over_accounts_tail++] = account;
}

function carried_over_accounts_dequeue() {
    if(carried_over_accounts_size() > 0) {
        return carried_over_accounts[carried_over_accounts_head++];
    }
}
