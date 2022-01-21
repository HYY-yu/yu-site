---
title: "Go 服务端开发总结"
date: 2022-01-21T09:56:39+08:00
draft: false
---

服务端开发一般是指业务的接口编写，对大部分系统来说，接口中CURD的操作占了绝大部分。然而，网络上总有调侃“CURD工程师”的梗，以说明此类开发技术并不复杂。但我个人认为，如果仅仅为了找个框架填充点代码完成任务，确实是简单，但是人类贵在是一根“会思考的芦苇”，如果深入的思考下去，在开发过程中还是会碰到很多通用的问题的。我们就用go的开发框架举例子，它有两种分化形式：
一种以[beego](https://beego.vip/)为代表的，[goframe](https://goframe.org/pages/viewpage.action?pageId=1114399)继续发扬广大的框架类型，它们的特点就是大而全，提供各种各样的功能，你甚至不需要做多少选择，反正按照文档使用就是了。它们的问题也就在于此，很多时候因为封装的太好了，很多问题都已经被无形地解决了（但不一定是最适合的解决方式）。
另一种则以[gin](https://gin-gonic.com/)、go-mirco等框架为代表，它们只解决特定一部分问题，使用它们虽然还有很多额外的工作要做，但是在之中也能学到更多的东西。
接下来，详细地看看go的服务端开发可能会碰到哪些问题：

### 1. 项目结构
无论是大项目还是小管理系统，万里长征第一步，都是如何组织自己的项目结构。在项目结构这方面，go其实没有一个固定的准则，因此可以根据实际情况，灵活的组织。但我觉得，还是需要知道一些需要注意的点：
##### 1. 包名简单，但要注意见名知意
这点在[这篇文章](https://go.dev/blog/package-names)中已经提到过了，用精炼的缩写代替冗长的包名，并且go中也经常出现`fmt`、`strconv`等常用缩写包，还有`pkg`、`cmd`等。但是我觉得，相比于简单，见名知意更重要。举个例子，我曾接手一个项目，它的根目录下就有一个`mdw`包，我开始还不知道这是干嘛的，看到里面放着一些 gin 的中间件才知道原来是`middleware`的缩写。
所以尽管go官方是推荐用一些约定俗成的、简洁的包名，但是应该要加个前提，那就是在注释中说明一下本包的作用，而注释却是在国内环境中，非常缺少的。所以与其生造一些缩写，又不写注释，那还不如把包名写的清楚一些。
##### 2. 使用 internal
使用 internal 有助于强制人思考，什么应该放在公共包，什么应该放在私有包，从而是项目结构更加清晰。而且go本身提供的包访问权限没有java那么详细，只有公开和私有这两种状态，更应该用internal来补充一下。
##### 3. 不要随便使用 init
说实话，我对为什么没有对init做任何限制还是有些疑虑的，这也就是说，你依赖的某些库可以先于你的程序代码运行，你也不知道它会做什么事（任何代码都可以在init中执行）。这在那种依赖非常多，又有很多间接依赖的大型项目中体现的很明显。尽管go官方要求不要在init中执行任何复杂的逻辑，但是这没有任何约束力。
最简单的例子就是单元测试，我有时候跑单元测试经常会碰到panic跑不起来，究其原因就是某些依赖库init中做了一些骚操作。但问题是：我是依赖的依赖（间接依赖）了这个库，我也没法控制它的代码（没有修改权限）。碰到这种情况，也只能在单元测试中完成它的要求才能继续运行。
所以把代码放在init中，一定要三思。就我来看，很多用init的代码确实在做初始化，但它们内部隐式依赖了文件、路径、资源等。这种情况要想一想，是不是可以用 NewXX() \ InitXX() 这种函数来替代。
##### 4. 慎用 util \ common 这种包名
这种一般是java程序员转过来的用的比较多，但其实在go中，是推荐有意义的包名来替代这种无意义的包名的。比如：`util.NewTimeHelper()` 就不好，应该写成`time_helper.New()` 这样可读性强一点。
但是我觉得具体情况还得具体分析，所以标题是慎用，而不是不用。因为有些时候，你的 util \ common 也就几个帮助函数，没多少东西。再细分成几个包感觉有点得不偿失了，等util \ common 再攒多一点再重构也不迟。所以还是回到开头提到的，多思考，灵活处理。
但是这里又要注意了，如果是那种被很多人依赖的公共 util \ common，最好还是早点拆分，不然后期可能拆不动了。
### 2. 代码结构
代码结构上能说道的东西就更多了，这可能是见软件设计功底的地方，我在这方面也是初学者，所以总结出来的可能对，可能不对，仅供参考。
##### 1. c \ s \ d 层的划分
得益于MVC的流行，即使现在已经普及了前后端分离的架构，大部分项目也仍然在内部存在 `controller`or`handler`、`service`or`svc`、`dao`or`repository`这样的划分。用于隔离数据展示、逻辑处理、数据存取的逻辑。这里记录下我对这三层划分的理解：
`controller`： 一般是入口控制器，做参数接收、转换，返回值处理、协议处理等工作。这一层一般不会太厚，也就是不会有太多的逻辑。这里要注意其与网关（Gateway）的区别，网关要做的事和能做的事会比它多很多。然后就是有些项目会把参数校验放在这一层，个人认为参数校验应该使用一些框架如`validator`来做，不要重复造轮子，如果需要访问数据库来校验参数，就应该放在`service`层做。
`service`：这层可能会比较重，也是很考验设计功力的地方，一不留神，就容易把这层变得耦合性极高。我也曾见过在`service`层中直接写sql查询的操作，十分让人头疼。总的来说，因为这一层承上启下，尽量让它成为一个粘合剂，而不是全能选手。
`dao`：这层就是跟数据相关了，其实就是把service层对数据的直接操作（操作数据库、redis），变成对方法的调用。以屏蔽数据库的差异，同时也可以做一些统一的数据处理。一般来说我们的项目会使用orm，这层也可以对orm进行一次封装，从而更易使用。由于这层更多的是对数据的通用化处理，所以一般通过代码生成器生成比较方便，比如：[gormt](https://github.com/xxjwxc/gormt)。
##### 2. 依赖的传递
这里的依赖指的是`controller`、`service`、`dao`层三者的依赖，一般来说，`controller`需要调用`service`，`service`需要调用`dao`。最忌讳的事是，因为上层需要下层，所以在上层中调用创建下层的代码，比如在`controller`的构造函数（就是NewXX，Go中没有专门设置构造函数）中调用`NewService`，这显然不符合单一职责的设计原则。所以一般有两种处理方式：
一、 设立全局变量
```go
var XX *XXService = &XXService{}

type XXService struct{
}

func (x *XXService) XX() {
}
```
这样，其他层直接调用这个全局变量即可。方便固然是方便，也容易带来两个问题：
	1. 随意调用
		这样不但上层可以调用，下层也可以调用。其实到处都能调的到，这样就很容易导致无法管理，尤其是在多人共同协作的项目中。
	2. 不能在 XXService 中持有字段
		持有字段必然涉及到如何初始化，要是放在init中，上面已经讲过，跑在init中是不太好的。如果设置一个`NewXX()`函数，那就不必设置这个全局变量了。
二、 设置NewXX()函数，通过依赖注入框架管理
```gp
type XXService struct{
	xRepo XXRepo
}

func NewXXService(r *XXRepo) *XXService {
	
}
```
然后通过依赖注入框架管理这些构造函数
```go
// wire.Build(repo.NewGoodsRepo, svc.NewGoodsSvc, controller.NewGoodsController)
// wire 框架自动生成
func initControllers() (*Controllers, error) {
	goodsRepo := repo.NewGoodsRepo()
	goodsSvc := svc.NewGoodsSvc( goodsRepo)
	goodsController := controller.NewGoodsController(goodsSvc)
	return goodsController, nil
}
```
这里，wire框架远没有java中的依赖注入框架那么牛逼，实际上，就是帮我们省了自己编写的麻烦。
这样Controller就持有了Service对象，Service就持有了Repo对象。而且，只有注册过的才能持有，避免了管理混乱的问题。
##### 3. 尽量避免全局变量
说到全局变量的问题，就不能不单独拿出来仔细说说。全局变量最典型的例子，就是logger了，众所周知，go提供的log包不是很好用，所以一般我们都会用一些开源的logger实现，很多实现都会提供一个默认的log（defaultLogger），方便使用，这本来也没什么。但是因为go本身错误处理提倡就地处理，也就是熟悉`if err != nil`，这就要命了。在一些大型项目中，可能很多函数、库的编写者，判断了错误后，顺手来个log打印出来；又或者不规范的到处打印调试日志。
这就导致我们在看程序日志时，可能会看到大量的垃圾日志，比如：一个错误被打印多次；或者打印的净是些没用地废话。每天的log数量可能就高达十几个G，不知道还以为业务有多繁忙，实际上，全是些废话日志。
在这方面做的比较好的就是`zap`，它就没有这种全局logger，你必须New一个对象出来，这就逼迫你思考，怎么保存这个对象？怎么把它传到需要打印日志的地方？但可惜，我也见过直接把zap日志对象赋给全局变量，然后继续疯狂使用的。
在使用gorm的时候，也会碰到这种问题，把返回的`gorm.DB`对象丢到全局变量，然后到处使用，这和logger会导致的问题也是一样的。
### 3. 可观察性的处理
可观察性是指日志、链路追踪、监控这三者的有机结合，具体的知识可以见附录的一些参考资料。可观察性其实也是在jaeger、prometheus流行后为大众所知，虽然历史不太久远，但是其重要性是不言而喻的。有效的解决了当线上服务出现问题时，快速的发现和定位具体位置，无论是大项目、小项目，微服务架构或者单体架构，都是非常必要的一环。
具体的配合上来说，首先可以通过prometheus这样的监控服务，及时发现服务存在异常，然后通过jaeger+log配合，寻找问题发生时的上下文，从而快速定位。
以前我未用过链路追踪、监控这些技术时，只靠打log，很多线上错误不能及时发现或者不能复现，其实是比较可惜的。但是要实现可观察性，多多少少都要改造一些代码，完全无侵入的改造是不可能的，所以在项目设计阶段，就可以考虑这方面的事情。从侵入性来说，监控<链路追踪<日志。
监控的侵入性最小，如接入prometheus，只要运行一个 sidecar 线程，处理prometheus的拉取请求即可，但是程序也要预先写好收集监控指标的代码；链路追踪更多的是要深入项目的各个层，比如：controller->service->dao->db，这样才能跟踪到整条请求链路；日志的侵入性肯定最大了，都是在业务代码中打印的。
##### 1.  db\redis\log 链路追踪处理
链路追踪的核心就是 context 了，在请求的开头生成一个追踪的上下文，各层来处理和传递这个context，如果是项目内部的代码，可以从context中解析出span，然后打印数据到span中。但是对于项目依赖的一些库(gorm\zap\redis等)，如果想把链路追踪到这些库的内部，这里就有两种处理方式：
1. 库本身就支持传递context
	比如：gorm就可以传递context进去，它虽然不能帮你解析这个上下文，但是提供了hook能力，可以自己编写一个plugin拿到这个上下文，自己处理即可。或者是go-micro这种框架，自动就处理了context的解析工作。
```go
// gorm示例
	// 使用插件
	err = db.Use(NewPlugin(WithDBName(dbName)))
	if err != nil {
		return nil, err
	}
	
	// 查询
	DB.WithContext(ctx).Find()
```
2. 库不支持传递context
	或者是库支持传递context，但是没提供hook能力。这种由于我们不能修改库的代码，又不能hook它内部的关键操作，就需要通过代理模式来接管对库的访问，比如：go-redis
```go
type Repo interface {
	Set(ctx context.Context, key, value string, ttl time.Duration, options ...Option) error
	Get(ctx context.Context, key string, options ...Option) (string, error)
	TTL(ctx context.Context, key string) (time.Duration, error)
	Expire(ctx context.Context, key string, ttl time.Duration) bool
	ExpireAt(ctx context.Context, key string, ttl time.Time) bool
	Del(ctx context.Context, key string, options ...Option) bool
	Exists(ctx context.Context, keys ...string) bool
	Incr(ctx context.Context, key string, options ...Option) int64
	Close() error
}

type cacheRepo struct {
	client *redis.Client
}
```
cacheRepo就是一个代理，内部持有私有的redis.Client对象，这样就能在`Set`、`Get`等时候，方便的做链路追踪的处理。这里展示一个`Get`方法的例子：
```go
func (c *cacheRepo) Get(ctx context.Context, key string, options ...Option) (string, error) {
	var err error
	ts := time.Now()
	opt := newOption()
	defer func() {
		if opt.TraceRedis != nil {
			opt.TraceRedis.Timestamp = time_parse.CSTLayoutString()
			opt.TraceRedis.Handle = "get"
			opt.TraceRedis.Key = key
			opt.TraceRedis.CostSeconds = time.Since(ts).Seconds()
			opt.TraceRedis.Err = err

			addTracing(ctx, opt.TraceRedis)
		}
	}()

	for _, f := range options {
		f(opt)
	}

	value, err := c.client.Get(ctx, key).Result()
	if err != nil {
		err = werror.Wrapf(err, "redis get key: %s err", key)
	}
	return value, err
}
```
##### 2.  中间件
这里的中间件指的是扩展go原生的http框架，从而支持请求方法链的三方框架，比如：gin、negroni等，这样我们就可以在一个请求的前后插入处理逻辑，比如：panic-recover、鉴权等。前面说到需要在请求的开头生成追踪的上下文，这个功能就可以在中间件来完成（如果是微服务架构，就应该在入口网关处就生成好）。
生成的追踪上下文，可以直接传到log中，这样后续请求链路中打印的log，就全部带上了TraceID，方便追踪。同时，请求的监控指标（QPS、响应时长等）也可以放在这个中间件中一起完成。
### 4. 错误处理
##### 1. Response Error 处理
一般来说，我们的接口返回都习惯返回一个错误码，用来处理一些业务逻辑错误。这个错误码有别于HTTP状态码，一般都是自己定义的一个错误码表，但是从标准性来考虑，我们在返回时还是要兼容一些常用的HTTP状态码的（400、404、500）等等。
这样，我们的 Response Error 就需要以下这些能力：
1. 隐藏程序错误，尤其是panic
	程序错误，尤其是panic，一旦抛出，容易让人分析出系统内部的实现细节，所以要注意隐藏。尤其是很多web框架会自动recover panic，然后打印出去。
2. 可以方便的定义HTTP状态码、错误码
	这里的方便指的是可以在service层指定返回的状态码、错误码，因为只有service层可以掌控全局。

实现起来很简单，只需实现以下五个方法：
```go
// 根据状态码、错误码、错误描述创建一个Error
func NewError(httpCode, businessCode int, msg string) Error {}
// 状态码默认200，根据错误码、错误描述创建一个Error
func NewErrorWithStatusOk(businessCode int, msg string) Error {}
// 状态码默认200，根据错误码创建一个Error（错误描述从 错误码表 中获取）
func NewErrorWithStatusOkAutoMsg(businessCode int) Error {}
// 根据状态码、错误码创建一个Error
func NewErrorAutoMsg(httpCode, businessCode int) Error {}
// 把内部的err放到 Error 中
func (e *err) WithErr(err error) Error {}
```
这个Error结构，就封装了状态码、错误码、错误描述和真正的error。使用时，示例代码如下：
```go
func (s *GoodsSvc) AddGoods(sctx core.SvcContext, param *model.GoodsAdd) error {
...
	if err != nil{
		return response.NewErrorAutoMsg(
			http.StatusInternalServerError,
			response.ServerError,
		).WithErr(err)
	}
```
##### 2. Go 的错误处理
既然写到了错误码，就不得不提一下Go中的错误处理，错误处理一直是Go中争议比较大的地方，就我们的日常开发而言，最常碰到的问题有三个，而Go的官方，也只是在1.13版本解决了其中一个。
1. 错误如何在各层传递
	由于在Go中，错误实际上只能包含一个字符串，所以对Go的程序员来说，如果要在错误中添加些额外信息，可能只能让原来的错误消失掉。到了1.13版本，通过`fmt.Errorf`支持了错误包装，才算解决了这一需求。
2. 如何获取到错误当时的堆栈
	但其实在日常开发中，还有一种是用的比较多的，那就是收集发生错误时的堆栈。这种堆栈信息的缺失对Go的新手们不太友好。
	试想两种情况：
	```go
	func Set(key string, value string) error{
		...
		return err 
	}
	```
	一个通用的Set函数，出现错误并返回时，如果它的上层调用者没有处理好，这个错误直接再往上抛，很容易就导致这个错误无法追溯到源头（就是知道这个错是Set抛出来，但是不知道是谁调用Set的）。
	第二种情况就是在内部处理时：
	```go
	func DoSomething(key string, value string) error{
		...
		err := io.Read()
		if err != nil{
			return fmt.Errors("Read: %w",err)
		}
		...  
		err = io.Read()
		if err != nil{
			return fmt.Errors("Read2: %w",err)
		}
	}
	```
	可以看到，一个函数内调用了多次函数（比如，调用Read读取文件），为了区分err，我们得包装每个错误，不然，你根本不知道是哪次的Read抛出来的问题。
	但是，这样写代码还是有些恶心，而且Go本身也没有什么好的处理方式。开源社区提供了很多错误包，比如：`github.com/pkg/errors`，就是用来为错误加入堆栈，从而方便的解决以上问题的。可惜，1.13的错误处理虽然参考了开源实现，但没有收录堆栈这个特性。
3. 如何聚合多个错误
	在一些特殊的场景，如在一连串的处理逻辑中，虽然发生错误，但是并不想中断逻辑，只是想记录下错误，然后继续。举个例子：
	有一个需求，统计系统每天晚上需要访问订单、商品、用户系统，从各个系统中拉取一些统计数据。我们可能会在统计系统中设置个定时任务，每晚去拉取即可，当拉取失败时，记录错误，并且继续拉取下一个。
```go
	func StartPull(){
		var errMulti error
		for i := range systems{
			if err := Pull(systems[i]); err != nil{
				errMulti = multierror.Append(errMulti, err)
			}
		}
	}
```

这里我们使用了`github.com/hashicorp/go-multierror` 这个库处理，其实就是个[]error数组。这里要注意的就是聚合多个错误和错误包装的区别，聚合错误时，多个错误间可以没有任何联系；错误包装多个错误间有上下级的关联。
### 5. dao层的处理
上面提到了 c / s / d 层的划分，以及各层的作用，这里想详细的讲下dao层。
##### 1. 自动生成代码
其实写多了dao层的代码就会发现，其中很多的代码都是通用化的，比如CURD的代码。无非是表的变动，逻辑都是一样的。这种代码非常适合使用生成器自动生成，比如：[`gormt`](https://github.com/xxjwxc/gormt)就可以自动生成gorm的CURD操作，用来写一些小系统非常轻松。
##### 2. 字段的隐藏
如果直接把数据库的表名、字段名写在代码里，肯定是不太好的实践。一般我们都要用一些结构体、常量来代替直接写在代码中。这方面，也可以通过工具来做自动生成，无需手动编写。比如：[`gormt`](https://github.com/xxjwxc/gormt)、[`gopo`](https://github.com/HYY-yu/gopo)等。
有了自动生成的字段名，加上强大的`GORM V2`框架，我们的dao层就能精简的提供上层需要的功能。
```go
func FindBy(id int, columns ...string){
    db.Select(colums).Find(&SomeTable{},id)
}
// 只取 ID Name 字段
bean := FindBy(1,dao.Colums.ID, dao.Colums.Name)
// 只取 Status 字段
bean := FindBy(2,dao.Colums.Status)
```
示例代码举了个简单的例子，通过一个`FindBy`函数，上层调用可以自由的控制自己想要获得的字段，并且不用暴露底层数据库的字段名。对于`Create`、`Update`等，也可以起到同样的控制效果，这里不再赘述。
##### 3. 更新字段
由于go的零值规定（0\false\""），字段的更新是一个容易出现问题的点。（我就经常在这上面写出bug）按道理说，我们提供的更新功能，应该满足一下几点：
1. 数据库零值跟go的零值对应
	在数据库的设计中，一般都提倡不使用NULL字段，而用默认值代替，这个默认值一般就是该类型的零值，这样跟go也是对应的。
2. 按需更新
	这里指的是接口设计时，规定传来的字段一定是要更新的字段，不需要更新的字段就不要出现。举个例子：
	```json
	// PUT /score
	{
		"id": 1,
		"name": "张三",
		"score": 100,
		"create_time": "2021-12-12"
	}
	```
	通过以上json，我们创建一条数据，这时该如何设计更新接口？
	```json
	// POST /score
	{	
		"id": 1,
		"name": "不对，我叫李四",
		"score": 0,
		"create_time": ""
	}
	```
	如上，假如规定零值字段不更新，只有非零值的字段参与更新。那么，如果用户真的想把`score`字段更新为0怎么办，实际上，零值和空值就产生了歧义。
	```json
	// POST /score
	{
		"id": 1,
		"name": "我叫李四"
	}
	```
	所以为了避免歧义，我们规定不更新的字段禁止出现在json中。同样的，在json转为go中的结构体时，我们也只能通过指针来接收：
	```go
	type UpdateScore struct{
		Id int 
		Name *string
		Score *int
		CreateTime *string
	}
	```
	不用指针接收，你还是没法判断，结构体中的Score等于0，到底是真的要设置为0，还是json中未传。
	虽然用指针看着就有点复杂了，但没办法，零值和空值的冲突问题，只能这样解决。或者，不用指针，我就指定更新接口的所有字段都必须传，全部更新到数据库（或者从数据库中读原始数据，对比有修改的字段就更新）。
	```json
	// POST /score
	{	
		"id": 1,
		"name": "不对，我叫李四",
		"score": 100,
		"create_time": "2021-12-12"
	}
	```
	可这样一来，还得读一次数据来对比，而且这个更新 的json会变得很大，传了很多冗余数据，我个人觉得更加的不可行。

### 6. 附录
虽然总结了5点事项，但我觉得，还有很多小知识点，其它的方面，可能不是一篇文章能写的尽的。若后期遇到或者碰到，也会继续总结出来。毕竟古人云，“学而时习之，不亦说乎”。没有总结，就看不到问题的全貌。
附上一些参考资料：

- [shop](https://github.com/HYY-yu/seckill.shop)
	我创建的一个示例项目，是一个完整的可运行的商品服务。文中的很多示例代码都是从这个项目中改造过来的，因为里面的代码都是处理过了上面说的哪些问题。
- [go-gin-api](https://github.com/xinliangnote/go-gin-api)
	感谢 `xinliangnote` 的项目，我是仔细研究过后，觉得对我的启发很大。很多代码、模块，都是从这里学到的。
- [GoFrame ](https://goframe.org/pages/viewpage.action?pageId=3672891)
	GoFrame虽然有点太大了，但不可否认，其中的代码、文档都是很系统很有参考性的。关于代码结构，它也有很详细的解读。
- [Kratos](https://go-kratos.dev/docs/guide/wire)
	kratos框架中这篇讲Wire的文章，比较通俗易懂。（相对于wire的官方文档而言）
- [GoFrame 链路追踪](https://goframe.org/pages/viewpage.action?pageId=3673684)
	还是推荐GoFrame，链路追踪也讲的很好。
 
