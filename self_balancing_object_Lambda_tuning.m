%%%%%%%%%%%%%%%%%%%%%%%% 导入数据的约定 %%%%%%%%%%%%%%%%%%%%%%%%%
% 假设 vofa 是已经导入的列向量数据
% 数据和时间对齐的例子
% OP：        0 0 0 X X
% PV：        0 0 0 0 2 
% 时间坐标轴： 0 1 2 3 4
% 此时，如果就取 OP 已经完成了阶跃响应之后的时间坐标轴第 3 个时刻作为新的时间坐标轴的原点
% 就会出现一些问题，比如注意看到 PV 在原坐标的 4 时刻就已经有了响应，而第 3 个时刻还是 0 
% 所以计算纯滞后时间要往后推，就是第 3 个时刻 - 第 2 个时刻 = 1 个时间单位
% 
% 所以就取 OP 和 PV 还都没完成阶跃响应，而 OP 即将开始阶跃响应的时刻作为原点
% 也就是说取 
% OP：        0 0 0 X X
% PV：        0 0 0 0 2
% 时间坐标轴： 0 1 2 3 4
%                 ↑ 这里开始导入数据（包括进来这里），并把第一列作为新的时间坐标轴原点 0 
%%%%%%%%%%%%%%%%%%%%%%% 设置一些其他信息，用来进行 lambda 整定 %%%%%%%%%%%%%%%%%%%%%%%
% 开环输出的阶跃变化量 ΔOP
delta_op = 5; % 是阶跃信号的幅值

% 过程变量上一次稳态的值，用来计算 ΔPV

last_steady_state_value = 0; % 这个值是在实际的过程中测量得到的，这里只是一个例子

% 过程变量和控制器输出的量程
op_max = 5;
pv_max = 1909.8116;

% 纯滞后时间 tau 会在后面的计算中得到
% 时间常数 T 会在后面的计算中得到
% 积分时间 Ti，一般取 8 * tau，会在后面的计算中得到
% 增益 K，会在后面的计算中得到
%%%%%%%%%%%%%%%%%%%%%%%%% 生成时间序列 %%%%%%%%%%%%%%%%%%%%%%%%%


data_length = length(vofa); % 获取数据列向量的长度

time_max = data_length - 1; % 时间序列的最大值

% 这里减去 1，因为第 1 列对应的是第 0 时刻
% 而 matlab 的索引是从 1 开始的，并且 (1:5) 这种结构就是自然语言的 1，2，3，4，5 
% 不像编程语言那样子，从 0 开始，左闭右开
% 所以这里减去 1 之后，就使得画图的坐标值是准的，不需要再减去 1 了
% 【而 matlab 里面的索引就是不准的】

time = linspace(0, time_max, data_length)';% 生成匹配长度的时间序列向量
% 假设取到
% OP：        0 X X
% PV：        0 0 2
% 时间坐标轴： 0 1 2
% 列向量索引： 1 2 3

%%%%%%%%%%%%%%%%%%%%%%%%% 找到最后一个零点并标记 %%%%%%%%%%%%%%%%%%%%%%%%%
% 设置容忍度
tolerance = 1e-5;


last_zero_index = find(vofa == 0, 1, 'last'); % find(A, n, 'first') 返回 A 中前 n 个满足条件的索引
% 按照上面的示例，返回的索引值是 2

% PV:         0 0 0 2
% 时间坐标轴： 0 1 2 3
% 列向量索引： 1 2 3 4

% 计算纯滞后时间
% tau = last_zero_index - 1; % 直接使用索引和自己定义的坐标轴偏移关系计算，不推荐
tau = time(last_zero_index) - time(1); % 把索引兑换成坐标，然后计算，推荐
disp(['纯滞后时间为：', num2str(tau),'个时间单位']);

% 绘制数据点及标记第一个非零点
figure;
plot(time, vofa, 'Color','#845ec2', 'DisplayName', '原始数据','LineWidth',2);
hold on;

scatter(time(last_zero_index), vofa(last_zero_index),  'Color','#ff6f91', 'LineWidth',2,'DisplayName', ['纯滞后时间\tau： ', num2str(tau), '个时间单位']);

%%%%%%%%%%%%%%%%%%%%%%%%% 计算稳态值及其标记 %%%%%%%%%%%%%%%%%%%%%%%%%
% 假设稳态水平从某个点开始到最后的平均值
% 从后往前遍历，找到第一个接近稳态值的点

% 从后往前遍历，找到第一个接近稳态值的点
steady_state_value = vofa(end);  % 初始化稳态值为最后一个数据点
sum_values = 0; % 工具变量，用于计算平均值
count = 0; % 工具变量，用于标记满足条件的点的个数
for i = data_length:-1:1
    if abs(vofa(i) - steady_state_value) < tolerance
        sum_values = sum_values + vofa(i);
        count = count + 1;
        steady_state_value = sum_values / count; % 更新稳态值为当前满足条件的所有点的平均值
    end
end 

% 标记稳态水平及第一个接近稳态的点，注意这里的稳态值是取到第一个稳态点的值
steady_state_index = find(abs(vofa - steady_state_value) < tolerance, 1, 'first');

% 遍历在这个点之后的所有点的数值，进行平均值得到稳态值
sum_values = 0; % 重新初始化工具变量
count = 0; % 重新初始化工具变量
for i = steady_state_index:data_length
    sum_values = sum_values + vofa(i);
    count = count + 1;
end
% 计算真正的稳态值
true_steady_state_value = sum_values / count;
disp(['稳态值为：',num2str(true_steady_state_value)]);


delta_pv = true_steady_state_value - last_steady_state_value; % 计算 Delta PV
disp(['\Delta PV 为：',num2str(delta_pv)]);
scatter(time(steady_state_index), vofa(steady_state_index),  'Color','#ff6f91', 'LineWidth',2,'DisplayName', ['从这里之后是稳态，\Delta PV：', num2str(delta_pv)]);

% %%%%%%%%%%%%%%%%%%%%%%%%% 计算 0.632 乘稳态值，并找到最接近的点 %%%%%%%%%%%%%%%%%%%%%%%%%
target_value = delta_pv * 0.632 + last_steady_state_value; % 计算变化到 63.2% Delta PV 时的数据点值

% 找到最后一个小于目标值的点的索引
lower_index = find(vofa <= target_value, 1, 'last');
% 找到第一个大于目标值的点的索引
upper_index = find(vofa >= target_value, 1, 'first');

% 进行加权平均计算出63.2%对应的假想横坐标，注意这里运算的不是索引了，是索引兑换成的坐标
weight_lower = abs(vofa(upper_index) - target_value);
weight_upper = abs(vofa(lower_index) - target_value);
weighted_time = (time(lower_index) * weight_upper + time(upper_index) * weight_lower) / ...
                (weight_lower + weight_upper);

delta_t = weighted_time - tau; % 计算从上一个稳态开始变大到这次 63.2% 稳态值的时间                

disp(['从原稳态变化到 63.2% 新稳态值的时间常数 T 为：',num2str(delta_t),'个时间单位']);

% 在图上标记出距离 63.2% 稳态值最近的两个点
scatter(time(lower_index), vofa(lower_index),  'Color','#ff6f91', 'LineWidth',2,'DisplayName', ['略低于 63.2% \Delta PV 的点，时间坐标为：', num2str(time(lower_index))]);
scatter(time(upper_index), vofa(upper_index),  'Color','#ff6f91', 'LineWidth',2,'DisplayName', ['略高于 63.2% \Delta PV 的点，时间坐标为：', num2str(time(upper_index))]);
scatter(weighted_time, target_value,  'Color','#ff6f91', 'LineWidth',2,'DisplayName', ['计算得到 63.2% \Delta PV 的点，时间坐标为：', num2str(weighted_time), '，时间常数 T 为：', num2str(delta_t), '个时间单位']);


%%%%%%%%%%%%%%%%%%%%%%%%%% lambda 整定 %%%%%%%%%%%%%%%%%%%%%%%%%

% 计算积分时间 Ti
Ti = delta_t;

% 计算增益 K
K = (delta_pv * op_max ) / (delta_op * pv_max);

Kp = delta_t / (K * 2 * tau);
Ki = Kp/Ti;

disp(['并联式 pid 系数:']);
disp(['Kp:',num2str(Kp,8)]);
disp(['Ki:',num2str(Ki,8)]);


%%%%%%%%%%%%%%%%%%%%%%%%% 添加图例和标签 %%%%%%%%%%%%%%%%%%%%%%%%%
legend('show');
xlabel('时间 (单位：/个时间单位)');
ylabel('幅值');
title('自衡对象开环阶跃响应曲线');

hold off;



