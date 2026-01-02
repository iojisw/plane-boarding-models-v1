clc; clear;

% --- 1. GLOBAL CONFIGURATION ---
total_rows = 63;            
entry_point_pbb1 = 1;       
entry_point_pbb2 = 7;       
pbb_length = 50;            
groups = [24, 80, 80, 80];  
total_pax = sum(groups);
max_time = 150000;          
plane_open_time = 5;        
prob_wrong_aisle = 0.02;    

% -- PENALTIES & DELAYS --
transfer_penalty = 15;      % Penalty for switching aisles
seat_shuffle_time = 25;     % Time added if blocked by seated passenger
reaction_delay_max = 2;     % Max hesitation ticks before moving

% We run 5 Scenarios
scenario_names = { ...
    '1. Sequential (G2-4 Wait)', ...
    '2. Parallel (Simultaneous)', ...
    '3. Mixed Arrival (Dual Bridge)', ...
    '4. Random (Single Bridge)', ...
    '5. Waves: (G1+G2) then (G3+G4)'};

% Modified: Results now stores [G1_Time, Total_Time]
results = zeros(5, 2); 

% --- 2. GENERATE PASSENGERS ---
master_pax.group = [];
master_pax.target_row = [];
master_pax.target_aisle = []; 
master_pax.seat_col = [];     
master_pax.assigned_pbb = []; 

for g = 1:4
    num_in_group = groups(g);
    master_pax.group = [master_pax.group, repmat(g, 1, num_in_group)];
    
    % --- ROW ASSIGNMENTS ---
    if g == 1
        rows = randi([1, 6], 1, num_in_group);
        assigned_bridge = 1;
    elseif g == 2
        rows = randi([44, 63], 1, num_in_group);
        assigned_bridge = 2;
    elseif g == 3
        rows = randi([25, 43], 1, num_in_group);
        assigned_bridge = 2;
    elseif g == 4
        rows = randi([7, 24], 1, num_in_group);
        assigned_bridge = 2;
    end
    
    aisles = randi([1, 2], 1, num_in_group);
    seat_cols = randi([1, 3], 1, num_in_group);
    
    master_pax.target_row = [master_pax.target_row, rows];
    master_pax.target_aisle = [master_pax.target_aisle, aisles];
    master_pax.seat_col = [master_pax.seat_col, seat_cols];
    master_pax.assigned_pbb = [master_pax.assigned_pbb, repmat(assigned_bridge, 1, num_in_group)];
end
pax_ids = 1:total_pax;

% --- START SCENARIO LOOP ---
for scen = 1:5
    fprintf('\n--- Running Scenario %s ---\n', scenario_names{scen});
    
    % Reset State
    pax_status = zeros(1, total_pax); 
    pax_pos = zeros(1, total_pax);        
    pax_current_aisle = zeros(1, total_pax); 
    pax_timer = zeros(1, total_pax); 
    pax_reaction = zeros(1, total_pax);
    seats_left = zeros(total_rows, 3);
    seats_right = zeros(total_rows, 3);
    pbb1_grid = zeros(1, pbb_length);
    pbb2_grid = zeros(1, pbb_length);
    aisle1_grid = zeros(1, total_rows);
    aisle2_grid = zeros(1, total_rows);
    
    pax_seated_count = 0;
    last_g1_seated_time = 0; 
    
    % --- QUEUE SETUP ---
    current_entry_pbb1 = entry_point_pbb1;
    current_entry_pbb2 = entry_point_pbb2;
    
    if scen == 1 || scen == 2
        queue_pbb1 = pax_ids(master_pax.assigned_pbb == 1);
        queue_pbb2 = pax_ids(master_pax.assigned_pbb == 2);
    elseif scen == 3
        shuffled = pax_ids(randperm(total_pax));
        queue_pbb1 = shuffled(master_pax.assigned_pbb(shuffled) == 1);
        queue_pbb2 = shuffled(master_pax.assigned_pbb(shuffled) == 2);
    elseif scen == 4
        queue_pbb1 = pax_ids(randperm(total_pax)); 
        queue_pbb2 = []; 
        current_entry_pbb1 = 1; 
    elseif scen == 5
        pool_A = pax_ids(ismember(master_pax.group, [1, 2]));
        pool_B = pax_ids(ismember(master_pax.group, [3, 4]));
        pool_A = pool_A(randperm(length(pool_A)));
        pool_B = pool_B(randperm(length(pool_B)));
        arrival_stream = [pool_A, pool_B];
        queue_pbb1 = arrival_stream(master_pax.assigned_pbb(arrival_stream) == 1);
        queue_pbb2 = arrival_stream(master_pax.assigned_pbb(arrival_stream) == 2);
    end
    
    idx_pbb1 = 1;
    idx_pbb2 = 1;
    
    % --- TIME LOOP ---
    for t = 1:max_time
        
        % 1. CHECK G1 COMPLETION
        g1_indices = find(master_pax.group == 1);
        if all(pax_status(g1_indices) == 4) && last_g1_seated_time == 0
            last_g1_seated_time = t;
        end

        % 2. IN-PLANE LOGIC (Seating)
        stowing_pax = find(pax_status == 3);
        for i = 1:length(stowing_pax)
            p = stowing_pax(i);
            pax_timer(p) = pax_timer(p) - 1;
            
            if pax_timer(p) <= 0
                pax_status(p) = 4; 
                pax_seated_count = pax_seated_count + 1;
                r = pax_pos(p);
                a = pax_current_aisle(p);
                c = master_pax.seat_col(p);
                if a == 1, aisle1_grid(r) = 0; seats_left(r, c) = 1;
                else, aisle2_grid(r) = 0; seats_right(r, c) = 1; end
            end
        end
        
        % 3. IN-PLANE MOVEMENT
        for r = total_rows:-1:1
            % AISLE 1
            pid = aisle1_grid(r);
            if pid > 0 && pax_status(pid) == 2
                target = master_pax.target_row(pid);
                if r < target
                    if r < total_rows && aisle1_grid(r+1) == 0
                        if pax_reaction(pid) > 0, pax_reaction(pid) = pax_reaction(pid) - 1;
                        else, aisle1_grid(r)=0; aisle1_grid(r+1)=pid; pax_pos(pid)=r+1; pax_reaction(pid)=randi([0, reaction_delay_max]); end
                    end
                elseif r == target
                    col = master_pax.seat_col(pid);
                    if rand() < 0.3, base_stow = 2; else, base_stow = randi([15, 45]); end
                    interference = 0;
                    if master_pax.target_aisle(pid) == 1
                        if col == 1 && (seats_left(r,2)==1 || seats_left(r,3)==1), interference = interference + 1; end
                        if col == 1 && seats_left(r,3)==1, interference = interference + 1; end % Count both seats if strictly blocked? Simplified:
                        % Let's stick to simple count of occupied seats between me and window
                        count = 0;
                        if col == 1, count = seats_left(r,2) + seats_left(r,3);
                        elseif col == 2, count = seats_left(r,3); end
                        interference = count;
                    else
                         count = 0;
                        if col == 1, count = seats_right(r,2) + seats_right(r,3);
                        elseif col == 2, count = seats_right(r,3); end
                        interference = count;
                    end
                    pax_status(pid) = 3; pax_timer(pid) = base_stow + (interference * seat_shuffle_time);
                end
            end
            
            % AISLE 2
            pid = aisle2_grid(r);
            if pid > 0 && pax_status(pid) == 2
                target = master_pax.target_row(pid);
                if r < target
                    if r < total_rows && aisle2_grid(r+1) == 0
                        if pax_reaction(pid) > 0, pax_reaction(pid) = pax_reaction(pid) - 1;
                        else, aisle2_grid(r)=0; aisle2_grid(r+1)=pid; pax_pos(pid)=r+1; pax_reaction(pid)=randi([0, reaction_delay_max]); end
                    end
                elseif r == target
                     col = master_pax.seat_col(pid);
                     if rand() < 0.3, base_stow = 2; else, base_stow = randi([15, 45]); end
                     interference = 0;
                     if master_pax.target_aisle(pid) == 2
                        if col == 1, interference = seats_right(r,2) + seats_right(r,3);
                        elseif col == 2, interference = seats_right(r,3); end
                     end
                     
                     if master_pax.target_aisle(pid) == 2
                        pax_status(pid) = 3; pax_timer(pid) = base_stow + (interference * seat_shuffle_time);
                     else
                        pax_status(pid) = 3; pax_timer(pid) = transfer_penalty + base_stow;
                     end
                end
            end
        end
        
        % 4. TRANSFER PBB -> PLANE
        if t > plane_open_time
            % PBB 1
            if pbb1_grid(end) > 0
                pid = pbb1_grid(end);
                real_target = master_pax.target_aisle(pid);
                if rand() < prob_wrong_aisle, chosen = 3 - real_target; else, chosen = real_target; end
                entered = false;
                if chosen == 1 && aisle1_grid(current_entry_pbb1) == 0, aisle1_grid(current_entry_pbb1)=pid; entered=true;
                elseif chosen == 2 && aisle2_grid(current_entry_pbb1) == 0, aisle2_grid(current_entry_pbb1)=pid; entered=true; end
                if entered, pbb1_grid(end)=0; pax_pos(pid)=current_entry_pbb1; pax_current_aisle(pid)=chosen; pax_status(pid)=2; pax_reaction(pid)=0; end
            end
            % PBB 2
            if pbb2_grid(end) > 0
                pid = pbb2_grid(end);
                real_target = master_pax.target_aisle(pid);
                if rand() < prob_wrong_aisle, chosen = 3 - real_target; else, chosen = real_target; end
                entered = false;
                if chosen == 1 && aisle1_grid(current_entry_pbb2) == 0, aisle1_grid(current_entry_pbb2)=pid; entered=true;
                elseif chosen == 2 && aisle2_grid(current_entry_pbb2) == 0, aisle2_grid(current_entry_pbb2)=pid; entered=true; end
                if entered, pbb2_grid(end)=0; pax_pos(pid)=current_entry_pbb2; pax_current_aisle(pid)=chosen; pax_status(pid)=2; pax_reaction(pid)=0; end
            end
        end
        
        % 5. PBB MOVEMENT
        for i = pbb_length-1:-1:1
            if pbb1_grid(i) > 0 && pbb1_grid(i+1) == 0, pbb1_grid(i+1)=pbb1_grid(i); pbb1_grid(i)=0; end
            if pbb2_grid(i) > 0 && pbb2_grid(i+1) == 0, pbb2_grid(i+1)=pbb2_grid(i); pbb2_grid(i)=0; end
        end
        
        % 6. FEEDING THE BRIDGES
        if idx_pbb1 <= length(queue_pbb1)
            if pbb1_grid(1) == 0
                pid = queue_pbb1(idx_pbb1);
                pbb1_grid(1) = pid; pax_status(pid) = 1; idx_pbb1 = idx_pbb1 + 1;
            end
        end
        
        can_feed_q2 = false;
        if scen == 1
            if idx_pbb1 > length(queue_pbb1) && sum(pbb1_grid) == 0, can_feed_q2 = true; end
        elseif scen == 2 || scen == 3 || scen == 5
            can_feed_q2 = true;
        elseif scen == 4
            can_feed_q2 = false; 
        end
        
        if can_feed_q2 && idx_pbb2 <= length(queue_pbb2)
            if pbb2_grid(1) == 0
                pid = queue_pbb2(idx_pbb2);
                pbb2_grid(1) = pid; pax_status(pid) = 1; idx_pbb2 = idx_pbb2 + 1;
            end
        end
        
        if pax_seated_count == total_pax
            break;
        end
    end
    
    % SAVE RESULTS: [G1 Time, Total Time]
    results(scen, 1) = last_g1_seated_time;
    results(scen, 2) = t;
    
    fprintf('  -> Finished at t=%d. Group 1 Finished at t=%d\n', t, last_g1_seated_time);
end

% --- DISPLAY RESULTS ---
fprintf('\n========================================================================================\n');
fprintf('REALISTIC SIMULATION RESULTS (Baseline: Scenario 1)\n');
fprintf('========================================================================================\n');
fprintf('%-35s | %-15s | %-15s | %-15s\n', 'Scenario', 'Time G1 (min)', 'Total (min)', 'Diff G1 vs S1');
fprintf('----------------------------------------------------------------------------------------\n');

baseline_g1 = results(1, 1); 

for i = 1:5
    val_g1 = results(i, 1) / 60;
    val_total = results(i, 2) / 60;
    
    diff_percent = ((results(i, 1) - baseline_g1) / baseline_g1) * 100;
    
    if i == 1
        fprintf('%-35s | %-15.2f | %-15.2f | %-15s\n', scenario_names{i}, val_g1, val_total, '---');
    else
        fprintf('%-35s | %-15.2f | %-15.2f | %+.2f%%\n', scenario_names{i}, val_g1, val_total, diff_percent);
    end
end
fprintf('========================================================================================\n');

% --- EXPLANATION TABLE (SCENARIO 2 vs 3) ---
fprintf('\n\n');
fprintf('ANALYSIS: DIFFERENCE BETWEEN SCENARIO 2 (PARALLEL) & 3 (MIXED)\n');
fprintf('====================================================================================================\n');
fprintf('%-20s | %-35s | %-35s\n', 'Feature', 'Scenario 2 (Parallel)', 'Scenario 3 (Mixed)');
fprintf('----------------------------------------------------------------------------------------------------\n');
fprintf('%-20s | %-35s | %-35s\n', 'Ordering', 'Sorted: Back-to-Front (G2->G3->G4)', 'Random (Shuffled Arrival)');
fprintf('%-20s | %-35s | %-35s\n', 'Aisle Blocking', 'Low (Front seats fill last)', 'High (Front pax block Back pax)');
fprintf('%-20s | %-35s | %-35s\n', 'Realism', 'Low (Requires strict gate control)', 'High (Realistic "Free-for-All")');
fprintf('%-20s | %-35s | %-35s\n', 'Bridge 2 Speed', 'Very Fast (Optimized Flow)', 'Slower (Stop-and-Go Traffic)');
fprintf('====================================================================================================\n');