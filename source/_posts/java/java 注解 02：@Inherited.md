---
title: 'java 注解 02：@Inherited '
tags:
  - java
categories: []
author: fengxiutianya
abbrlink: ca158b7a
date: 2019-03-04 07:22:00
---
# java 注解 02：`@Inherited `

`@Inherited` 作用：**注解继承声明，是否允许子类继承该注解**

下面看具体示例

### **自定义注解标记在类上的继承情况**

**1、自定义注解**

```java
@Inherited // 可以被继承
@Retention(java.lang.annotation.RetentionPolicy.RUNTIME) // 可以通过反射读取注解
public @interface BatchExec {
    String value();
}
```

<!-- more -->

2、被注解的父类

```java
@BatchExec(value = "类名上的注解")
public abstract class ParentClass {

    @BatchExec(value = "父类的abstractMethod方法")
    public abstract void abstractMethod();

    @BatchExec(value = "父类的doExtends方法")
    public void doExtends() {
        System.out.println(" ParentClass doExtends ...");
    }

    @BatchExec(value = "父类的doHandle方法")
    public void doHandle() {
        System.out.println(" ParentClass doHandle ...");
    }
    
}
```

子类：

```java
public class SubClass1 extends ParentClass {

    // 子类实现父类的抽象方法
    @Override
    public void abstractMethod() {
        System.out.println("子类实现父类的abstractMethod抽象方法");
    }

    //子类继承父类的doExtends方法

    // 子类覆盖父类的doHandle方法
    @Override
    public void doHandle() {
        System.out.println("子类覆盖父类的doHandle方法");
    }
    
}
```

测试类：

```java
public class MainTest1 {
    public static void main(String[] args) 
    			throws SecurityException, NoSuchMethodException {

        Class<SubClass1> clazz = SubClass1.class;

        if (clazz.isAnnotationPresent(BatchExec.class)) {
            BatchExec cla = clazz.getAnnotation(BatchExec.class);
            System.out.println("类：子类可继承");
        } else {
            System.out.println("类：子类不能继承到父类类上Annotation");
        }

        // 实现抽象方法测试
        Method method = clazz.getMethod("abstractMethod", new Class[] {});
        if (method.isAnnotationPresent(BatchExec.class)) {
            BatchExec ma = method.getAnnotation(BatchExec.class);
            System.out.println("子类实现抽象方法：子类可继承");
        } else {
            System.out.println("子类实现抽象方法：没有继承到父类抽象方法中的Annotation");
        }

        // 子类未重写的方法
        Method methodOverride = clazz.getMethod("doExtends", new Class[] {});
        if (methodOverride.isAnnotationPresent(BatchExec.class)) {
            BatchExec ma = methodOverride.getAnnotation(BatchExec.class);
            System.out.println("子类未实现方法：子类可继承，注解读取='" + ma.value() + "'");
        } else {
            System.out.println("子类未实现方法：没有继承到父类doExtends方法中的Annotation");
        }

        // 子类重写的方法
        Method method3 = clazz.getMethod("doHandle", new Class[] {});
        if (method3.isAnnotationPresent(BatchExec.class)) {
            BatchExec ma = method3.getAnnotation(BatchExec.class);
            System.out.println("子类覆盖父类的方法：继承到父类doHandle方法中的Annotation“);
        } else {
            System.out.println("子类覆盖父类的方法:没有继承到父类doHandle方法中的Annotation");
        }

        // 子类重写的方法
        Method method4 = clazz.getMethod("doHandle2", new Class[] {});
        if (method4.isAnnotationPresent(BatchExec.class)) {
            BatchExec ma = method4.getAnnotation(BatchExec.class);
            System.out.println("子类未实现方法doHandle2：子类可继承");
        } else {
            System.out.println("子类未实现方法doHandle2：没有继承到父类doHandle2方法中的Annotation");
        }
    }
}
```

结果：

```
类：子类可继承，
子类实现抽象方法：没有继承到父类抽象方法中的Annotation
子类未实现方法：  子类可继承
子类覆盖父类的方法:没有继承到父类doHandle方法中的Annotation
子类未实现方法doHandle2：没有继承到父类doHandle2方法中的Annotation
```

### **自定义注解标记在接口上的继承情况**

```java
@BatchExec(value = "接口上的注解")
public interface Parent {
    void abstractMethod();
}
```

接口的继承类

```java
public abstract class ParentClass3  {

    public void abstractMethod() {
        System.out.println("ParentClass3");    
    }

    @BatchExec(value = "父类中新增的doExtends方法")
    public void doExtends() {
        System.out.println(" ParentClass doExtends ...");
    }
}
```

该继承类的注解可见测试：

```java
public class MainTest3 {
    public static void main(String[] args) 
        	throws SecurityException, NoSuchMethodException {

        Class<ParentClass3> clazz = ParentClass3.class;

        if (clazz.isAnnotationPresent(BatchExec.class)) {
            BatchExec cla = clazz.getAnnotation(BatchExec.class);
            System.out.println("类：子类可继承");
        } else {
            System.out.println("类：子类不能继承到接口类上Annotation");
        }

        // 实现抽象方法测试
        Method method = clazz.getMethod("abstractMethod", new Class[] {});
        if (method.isAnnotationPresent(BatchExec.class)) {
            BatchExec ma = method.getAnnotation(BatchExec.class);
            System.out.println("子类实现抽象方法：子类可继承");
        } else { 
            System.out.println("子类实现抽象方法：没有继承到接口抽象方法中的Annotation");
        }

        //子类中新增方法
        Method methodOverride = clazz.getMethod("doExtends", new Class[] {});
        if (methodOverride.isAnnotationPresent(BatchExec.class)) {
            BatchExec ma = methodOverride.getAnnotation(BatchExec.class);
            System.out.println("子类中新增方法：可被读取注解");
        } else {
            System.out.println("子类中新增方法：不能读取注解");
        }

    }
}
```

结果：

```
类：子类不能继承到接口类上Annotation
子类实现抽象方法：没有继承到接口抽象方法中的Annotation
子类中新增方法：注解读取='父类中新增的doExtends方法
```

子类的子类注解继承情况：

```java
public class SubClass3 extends ParentClass3 {

    // 子类实现父类的抽象方法
    @Override
    public void abstractMethod() {
        System.out.println("子类实现父类的abstractMethod抽象方法");
    }

    // 子类覆盖父类的doExtends方法
}
```

测试类：

```java
public class MainTest33 {
    public static void main(String[] args) throws SecurityException, NoSuchMethodException {

        Class<SubClass3> clazz = SubClass3.class;

        if (clazz.isAnnotationPresent(BatchExec.class)) {
            BatchExec cla = clazz.getAnnotation(BatchExec.class);
            System.out.println("类：子类可继承");
        } else {
            System.out.println("类：子类不能继承到父类类上Annotation");
        }

        // 实现抽象方法测试
        Method method = clazz.getMethod("abstractMethod", new Class[] {});
        if (method.isAnnotationPresent(BatchExec.class)) {
            BatchExec ma = method.getAnnotation(BatchExec.class);
            System.out.println("子类实现抽象方法：子类可继承");
        } else { 
            System.out.println("子类实现抽象方法：没有继承到父类抽象方法中的Annotation");
        }

        //子类未重写的方法
        Method methodOverride = clazz.getMethod("doExtends", new Class[] {});
        if (methodOverride.isAnnotationPresent(BatchExec.class)) {
            BatchExec ma = methodOverride.getAnnotation(BatchExec.class);
            System.out.println("子类未实现方法：子类可继承");
        } else {
            System.out.println("子类未实现方法：没有继承到父类doExtends方法中的Annotation");
        }

    }
}
```

结果：

```
类：子类不能继承到父类类上Annotation
子类实现抽象方法：没有继承到父类抽象方法中的Annotation
子类未实现方法：子类可继承
```

### 总结

从上面可以看出，被`@Inherited`标记过的注解，标记在类上面可以被子类继承，标记在方法上，如果子类实现了此方法，则不能继承此注解，如果子类是继承了方法，而没有重新实现方法则可以继承此方法的注解。