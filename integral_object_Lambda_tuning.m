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
%
%%%%%%%%%%%%%%%%%%%%%%% 设置一些其他信息，用来进行 lambda 整定 %%%%%%%%%%%%%%%%%%%%%%%
% 开环输出的阶跃变化量 ΔOP
delta_op = 255; % 是阶跃信号的幅值

% 过程变量上一次稳态的值，用来计算 ΔPV
last_steady_state_value = 0; % 这个值是在实际的过程中测量得到的，这里只是一个例子

% 过程变量和控制器输出的量程
op_max = 255;
% pv_max = ; % 因为这是积分对象，所以 pv_max 是无穷大的，得看自己实际的测量工具的量程

% 纯滞后时间 tau 会在后面的计算中得到
% 等效时间常数 ΔT 会在后面的计算中得到
% 积分时间 Ti，一般取 8 * tau，会在后面的计算中得到
% 等效增益 K，会在后面的计算中得到
%
%%%%%%%%%%%%%%%%%%%%%%%%% 生成时间序列 %%%%%%%%%%%%%%%%%%%%%%%%%

% 使用前先导入 vofa 的数据，并【大概】确定从哪里开始是线性的
linear_time_begin = 100;

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

% 找到直线部分的数据
linear_time = time(time >= linear_time_begin);
linear_data = vofa(time >= linear_time_begin);

%%%%%%%%%%%%%%%%%%%%%%%%% 处理积分对象 1 ：绘制开环响应阶跃曲线 %%%%%%%%%%%%%%%%%%%%%%%%
% 线性拟合以找到直线部分的斜率和截距
coefficients = polyfit(linear_time, linear_data, 1);
% coefficients 是拟合出来的系数列表
slope_fit = coefficients(1); % slope 斜率
intercept_fit = coefficients(2); % intercept 截距

% 计算直线延长后与 x 轴的交点
x_intercept_fit = -intercept_fit / slope_fit; % 这个交点就是坐标单位，不是索引

tau = x_intercept_fit; % 纯滞后时间

% 数据和延长线绘图
figure;
hold on;

plot(time, vofa, 'Color','#845ec2', 'DisplayName', '原始数据','LineWidth',2);
plot([min(time), max(time)], slope_fit * [min(time), max(time)] + intercept_fit, '--', 'Color','#d65db1','LineWidth',2,'DisplayName', '线性拟合的延长线');
scatter(x_intercept_fit, 0, 'Color','#ff6f91', 'LineWidth',2,'DisplayName', ['交点时间坐标为：',num2str(x_intercept_fit), '，也就是纯滞后时间 \tau 为： ', num2str(tau), '个时间单位']);

xlabel('时间 (单位：/个时间单位)');
ylabel('幅值');
title('线性拟合开环阶跃响应曲线');
legend;
grid on;
hold off;

% 打印交点信息
disp(['拟合的直线与 x 轴的交点，也就是纯滞后时间 \tau 为: ', num2str(tau)]);

%%%%%%%%%%%%%%%%%%%%%%% 处理积分对象 2：lambda 整定 %%%%%%%%%%%%%%%%%%%%%%

calculate_data = vofa(time >= tau);
calculate_time = time(time >= tau);


% 计算 ΔPV
delta_pv = calculate_data - last_steady_state_value;
% 计算 ΔT
delta_t = calculate_time - tau;
% 计算积分时间 Ti
Ti = 8 * tau;
% 计算等效增益 K
K = delta_pv / delta_op;

% 初始化 Kp 和 Ki 列向量
Kp = zeros(size(calculate_time));
Ki = zeros(size(calculate_time));

% 计算比例增益 Kp 和积分时间 Ki
for i = 1:length(calculate_time)
    Kp(i) = delta_t(i) / (K(i) * 2 * tau);
    Ki(i) = Kp(i) / Ti;
end

% 在新的窗口中绘制图像
figure;
plot(calculate_time, Kp, 'b', 'LineWidth', 2);
xlabel('时间 (单位：/个时间单位)');
ylabel('Kp');
title('lambda 整定的 Kp');
grid on;

% 绘制 Ki 图像
figure;
plot(calculate_time, Ki, 'r', 'LineWidth', 2);
xlabel('时间 (单位：/个时间单位)');
ylabel('Ki');
title('lambda 整定的 Ki');
grid on;






